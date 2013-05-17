require 'rest-client'
require 'time'
require 'openssl'
require 'base64'

module S3File
  def get_md5_from_s3(bucket,path,aws_access_key_id,aws_secret_access_key)
    return get_digests_from_s3(bucket,path,aws_access_key_id,aws_secret_access_key)["md5"]
  end
  
  def get_digests_from_s3(bucket,path,aws_access_key_id,aws_secret_access_key)
    now, auth_string = get_s3_auth("HEAD", bucket,path,aws_access_key_id,aws_secret_access_key)
    response = RestClient.head('https://%s.s3.amazonaws.com%s' % [bucket,path], :date => now, :authorization => auth_string)
    
    etag = response.headers[:etag].gsub('"','')
    digest = response.headers[:x_amz_meta_digest]
    digests = Hash[digest.split(",").map {|a| a.split("=")}]

    return {"md5" => etag}.merge(digests)
  end

  def get_from_s3(bucket,path,aws_access_key_id,aws_secret_access_key)    
    now, auth_string = get_s3_auth("GET", bucket,path,aws_access_key_id,aws_secret_access_key)
    response = RestClient.get('https://%s.s3.amazonaws.com%s' % [bucket,path], :date => now, :authorization => auth_string)

    return response.body
  end

  def get_s3_auth(method, bucket,path,aws_access_key_id,aws_secret_access_key)
    now = Time.now().utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
    string_to_sign = "#{method}\n\n\n%s\n/%s%s" % [now,bucket,path]

    digest = digest = OpenSSL::Digest::Digest.new('sha1')
    signed = OpenSSL::HMAC.digest(digest, aws_secret_access_key, string_to_sign)
    signed_base64 = Base64.encode64(signed)

    auth_string = 'AWS %s:%s' % [aws_access_key_id,signed_base64]

    [now,auth_string]
  end
end
