include S3File

action :create do
  new_resource = @new_resource

  body = get_from_s3(new_resource.bucket, new_resource.remote_path, new_resource.aws_access_key_id, new_resource.aws_secret_access_key).body

  file new_resource.path do
    owner new_resource.owner if new_resource.owner
    group new_resource.group if new_resource.group
    mode new_resource.mode if new_resource.mode
    action :create
    content body
  end
end
