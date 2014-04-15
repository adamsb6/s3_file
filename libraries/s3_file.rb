require 'rest-client'
require 'time'
require 'openssl'
require 'base64'

module S3FileLib
  BLOCKSIZE_TO_READ = 1024 * 1000
  RestClient.proxy = ENV['http_proxy']
  
  def self.build_headers(date, authorization, token)
    headers = {
      :date => date,
      :authorization => authorization
    }
    if token
      headers['x-amz-security-token'] = token
    end
        
    return headers
  end
  
  def self.get_md5_from_s3(bucket,path,aws_access_key_id,aws_secret_access_key,token)
    return get_digests_from_s3(bucket,path,aws_access_key_id,aws_secret_access_key,token)["md5"]
  end
  
  def self.get_digests_from_s3(bucket,path,aws_access_key_id,aws_secret_access_key,token)
    now, auth_string = get_s3_auth("HEAD", bucket,path,aws_access_key_id,aws_secret_access_key, token)
    
    headers = build_headers(now, auth_string, token)
    response = RestClient.head('https://%s.s3.amazonaws.com%s' % [bucket,path], headers)
    
    etag = response.headers[:etag].gsub('"','')
    digest = response.headers[:x_amz_meta_digest]
    digests = digest.nil? ? {} : Hash[digest.split(",").map {|a| a.split("=")}]

    return {"md5" => etag}.merge(digests)
  end

  def self.get_from_s3(bucket,path,aws_access_key_id,aws_secret_access_key,token)   
    now, auth_string = get_s3_auth("GET", bucket,path,aws_access_key_id,aws_secret_access_key, token)
    
    headers = build_headers(now, auth_string, token)
#    response = RestClient.get('https://%s.s3.amazonaws.com%s' % [bucket,path], headers)
    response = RestClient::Request.execute(:method => :get, :url => 'https://%s.s3.amazonaws.com%s' % [bucket,path], :raw_response => true, :headers => headers)

    return response
  end

  def self.get_s3_auth(method, bucket,path,aws_access_key_id,aws_secret_access_key, token)
    now = Time.now().utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
    string_to_sign = "#{method}\n\n\n%s\n" % [now]
    
    if token
      string_to_sign += "x-amz-security-token:#{token}\n"
    end
    
    string_to_sign += "/%s%s" % [bucket,path]

    digest = digest = OpenSSL::Digest::Digest.new('sha1')
    signed = OpenSSL::HMAC.digest(digest, aws_secret_access_key, string_to_sign)
    signed_base64 = Base64.encode64(signed)

    auth_string = 'AWS %s:%s' % [aws_access_key_id,signed_base64]
        
    [now,auth_string]
  end

  def self.aes256_decrypt(key, file)
    Chef::Log.debug("Decrypting S3 file.")
    key = key.strip
    require "digest"
    key = Digest::SHA256.digest(key) if(key.kind_of?(String) && 32 != key.bytesize)
    aes = OpenSSL::Cipher.new('AES-256-CBC')
    aes.decrypt
    aes.key = key
    decrypt_file = Tempfile.new("chef-s3-decrypt")
    File.open(file, "rb") do |fi|
      while buffer = fi.read(BLOCKSIZE_TO_READ)
        aes.update(buffer)
        decrypt_file.write buffer
      end
    end
    decrypt_file.write aes.final
    decrypt_file.close
    decrypt_file
  end
end
