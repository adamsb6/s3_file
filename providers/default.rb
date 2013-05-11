include S3File

require 'digest/md5'

action :create do
  new_resource = @new_resource
  download = true
  
  if ::File.exists? new_resource.path
    s3_md5 = get_md5_from_s3(new_resource.bucket, new_resource.remote_path, new_resource.aws_access_key_id, new_resource.aws_secret_access_key)
  
    current_md5 = Digest::MD5.hexdigest(::File.read(new_resource.path))
  
    if current_md5 == s3_md5 then
      Chef::Log.debug 'Skipping download, md5sum of local file matches file in S3.'
      download = false
    end
  end
  
  if download
    body = get_from_s3(new_resource.bucket, new_resource.remote_path, new_resource.aws_access_key_id, new_resource.aws_secret_access_key).body

    file new_resource.path do
      owner new_resource.owner if new_resource.owner
      group new_resource.group if new_resource.group
      mode new_resource.mode if new_resource.mode
      action :create
      content body
    end
  end
end
