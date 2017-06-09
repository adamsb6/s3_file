require 'digest/md5'
require 'json'
require 'cgi'

use_inline_resources

action :create do
  @run_context.include_recipe 's3_file::dependencies'
  client = S3FileLib.client
  download = true

  # handle key specified without leading slash, and support URL encoding when necessary.
  remote_path = ::File.join('', new_resource.remote_path).split('/').map{|x| CGI.escape(x)}.join('/')

  # we need credentials to be mutable
  aws_access_key_id = new_resource.aws_access_key_id
  aws_secret_access_key = new_resource.aws_secret_access_key
  token = new_resource.token
  decryption_key = new_resource.decryption_key
  region = new_resource.aws_region

  Chef::Log.debug("credentials received [aws_access_key_id:%s, aws_secret_access_key:%s, token:%s]" % [!aws_access_key_id.nil?, !aws_secret_access_key.nil?, !token.nil?])
  # if credentials not set, try instance profile
  if aws_access_key_id.nil? && aws_secret_access_key.nil? && token.nil?
    if new_resource.public_bucket
      aws_access_key_id = ''
      aws_secret_access_key = ''
      token = ''
    else
      instance_profile_base_url = 'http://169.254.169.254/latest/meta-data/iam/security-credentials/'
      begin
        instance_profiles = client.get(instance_profile_base_url)
      rescue client::ResourceNotFound, Errno::ETIMEDOUT # set 404 on an EC2 instance
        raise ArgumentError.new 'No credentials provided and no instance profile on this machine.'
      end
      instance_profile_name = instance_profiles.split.first
      instance_profile = JSON.load(client.get(instance_profile_base_url + instance_profile_name))

    aws_access_key_id = instance_profile['AccessKeyId']
    aws_secret_access_key = instance_profile['SecretAccessKey']
    token = instance_profile['Token']

    # now try to auto-detect the region from the instance
      if region.nil?
        dynamic_doc_base_url = 'http://169.254.169.254/latest/dynamic/instance-identity/document'
        begin
          dynamic_doc = JSON.load(client.get(dynamic_doc_base_url))
          region = dynamic_doc['region']
        rescue Exception => e
          Chef::Log.debug "Unable to auto-detect region from instance-identity document: #{e.message}"
        end
      end
    end
  end

  if ::File.exists?(new_resource.path)
    s3_etag = S3FileLib::get_md5_from_s3(new_resource.bucket, new_resource.s3_url, remote_path, aws_access_key_id, aws_secret_access_key, token, new_resource.public_bucket)

    if decryption_key.nil?
      if new_resource.decrypted_file_checksum.nil?
        if S3FileLib::verify_md5_checksum(s3_etag, new_resource.path)
          Chef::Log.debug 'Skipping download, md5sum of local file matches file in S3.'
          download = false
        end
      #we have a decryption key so we must switch to the sha256 checksum
      else
        if S3FileLib::verify_sha256_checksum(new_resource.decrypted_file_checksum, new_resource.path)
          Chef::Log.debug 'Skipping download, sha256 of local file matches recipe.'
          download = false
        end
      end
      # since our resource is a decrypted file, we must use the
      # checksum provided by the resource to compare to the local file
    else
      unless new_resource.decrypted_file_checksum.nil?
        if S3FileLib::verify_sha256_checksum(new_resource.decrypted_file_checksum, new_resource.path)
          Chef::Log.debug 'Skipping download, sha256 of local file matches recipe.'
          download = false
        end
      end
    end

    # Don't download if content and etag match prior download
    if node['s3_file']['use_catalog']
      catalog_data = S3FileLib::catalog.fetch(new_resource.path, nil)
      existing_file_md5 = S3FileLib::buffered_md5_checksum(new_resource.path)
      if catalog_data && existing_file_md5 == catalog_data['local_md5'] && s3_etag == catalog_data['etag']
        Chef::Log.debug 'Skipping download, md5 of local file and etag matches prior download.'
        download = false
      end
    end
  end

  if download
    response = S3FileLib::get_from_s3(new_resource.bucket, new_resource.s3_url, remote_path, aws_access_key_id, aws_secret_access_key, token,region, new_resource.verify_md5, new_resource.public_bucket)

    # not simply using the file resource here because we would have to buffer
    # whole file into memory in order to set content this solves
    # https://github.com/adamsb6/s3_file/issues/15
    unless decryption_key.nil?
      begin
        decrypted_file = S3FileLib::aes256_decrypt(decryption_key,response.file.path)
      rescue OpenSSL::Cipher::CipherError => e

        Chef::Log.error("Error decrypting #{name}, is decryption key correct?")
        Chef::Log.error("Error message: #{e.message}")

        raise e
      end

      downloaded_file = decrypted_file
    else
      downloaded_file = response.file
    end

    # Write etag and md5 to catalog for future reference
    if node['s3_file']['use_catalog']
      catalog = S3FileLib::catalog
      catalog[new_resource.path] = {
        'etag' => response.headers[:etag].gsub('"',''),
        'local_md5' => S3FileLib::buffered_md5_checksum(downloaded_file.path)
      }
      S3FileLib::write_catalog(catalog)
    end

    # Take ownership and permissions from existing object
    if ::File.exist?(new_resource.path)
      stat = ::File::Stat.new(new_resource.path)
      ::FileUtils.chown(stat.uid, stat.gid, downloaded_file)
      ::FileUtils.chmod(stat.mode, downloaded_file)
    end
    ::FileUtils.mv(downloaded_file.path, new_resource.path)
  end

  f = file new_resource.path do
    action :create
    owner new_resource.owner || ENV['USER']
    group new_resource.group || ENV['USER']
    mode new_resource.mode || '0644'
  end

  new_resource.updated_by_last_action(download || f.updated_by_last_action?)
end
