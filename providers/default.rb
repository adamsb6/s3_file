#include S3File

require 'digest/md5'
require 'rest-client'
require 'json'

action :create do
  new_resource = @new_resource
  download = true
  
  # handle key specified without leading slash
  remote_path = new_resource.remote_path
  if remote_path.chars.first != '/'
    remote_path = "/#{remote_path}"
  end
  
  # we need credentials to be mutable
  aws_access_key_id = new_resource.aws_access_key_id
  aws_secret_access_key = new_resource.aws_secret_access_key
  token = new_resource.token
  
  # if credentials not set, try instance profile
  if new_resource.aws_access_key_id.nil? and new_resource.aws_secret_access_key.nil? and new_resource.token.nil?
    instance_profile_base_url = 'http://169.254.169.254/latest/meta-data/iam/security-credentials/'
    begin
      instance_profiles = RestClient.get(instance_profile_base_url)
    rescue RestClient::ResourceNotFound, Errno::ETIMEDOUT # we can either 404 on an EC2 instance, or timeout on non-EC2
      raise ArgumentError.new 'No credentials provided and no instance profile on this machine.'
    end
    instance_profile_name = instance_profiles.split.first
    instance_profile = JSON.load(RestClient.get(instance_profile_base_url + instance_profile_name))
    
    aws_access_key_id = instance_profile['AccessKeyId']
    aws_secret_access_key = instance_profile['SecretAccessKey']
    token = instance_profile['Token']
  end
    
  if ::File.exists? new_resource.path
    s3_md5 = S3FileLib::get_md5_from_s3(new_resource.bucket, remote_path, aws_access_key_id, aws_secret_access_key, token)
    
    current_md5 = Digest::MD5.hexdigest(::File.read(new_resource.path))
    
    Chef::Log.debug "md5 of S3 object is #{s3_md5}"
    Chef::Log.debug "md5 of local object is #{current_md5}"
    
    if current_md5 == s3_md5 then
      Chef::Log.debug 'Skipping download, md5sum of local file matches file in S3.'
      download = false
    end
  end
  
  if download
    body = S3FileLib::get_from_s3(new_resource.bucket, remote_path, aws_access_key_id, aws_secret_access_key, token).body

    file new_resource.path do
      owner new_resource.owner if new_resource.owner
      group new_resource.group if new_resource.group
      mode new_resource.mode if new_resource.mode
      action :create
      content body
    end
    @new_resource.updated_by_last_action(true)
  end
end
