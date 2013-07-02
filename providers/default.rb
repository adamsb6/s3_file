#include S3File

require 'digest/md5'

action :create do
  new_resource = @new_resource
  download = true
  
  # handle key specified without leading slash
  remote_path = new_resource.remote_path
  if remote_path.chars.first != '/'
    remote_path = "/#{remote_path}"
  end
    
  if ::File.exists? new_resource.path
    s3_md5 = S3FileLib::get_md5_from_s3(new_resource.bucket, remote_path, new_resource.aws_access_key_id, new_resource.aws_secret_access_key)
    
    current_md5 = Digest::MD5.hexdigest(::File.read(new_resource.path))
    
    Chef::Log.debug "md5 of S3 object is #{s3_md5}"
    Chef::Log.debug "md5 of local object is #{current_md5}"
    
    if current_md5 == s3_md5 then
      Chef::Log.debug 'Skipping download, md5sum of local file matches file in S3.'
      download = false
    end
  end
  
  if download
    body = S3FileLib::get_from_s3(new_resource.bucket, remote_path, new_resource.aws_access_key_id, new_resource.aws_secret_access_key).body

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
