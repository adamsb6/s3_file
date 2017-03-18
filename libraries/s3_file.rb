require 'time'
require 'openssl'
require 'base64'

module S3FileLib

  module SigV2
  def self.sign(request, bucket, path, *args)
      token = args[2] if args[2]
      now = Time.now().utc.strftime('%a, %d %b %Y %H:%M:%S GMT')
      string_to_sign = "#{request.method}\n\n\n%s\n" % [now]

      string_to_sign += "x-amz-security-token:#{token}\n" if token

      string_to_sign += "/%s%s" % [bucket,path]

      digest = OpenSSL::Digest.new('sha1')
      signed = OpenSSL::HMAC.digest(digest, args[1], string_to_sign)
      signed_base64 = Base64.encode64(signed)

      auth_string = 'AWS %s:%s' % [args[0], signed_base64]

      request["date"] = now
      request["authorization"] = auth_string.strip
      request["x-amz-security-token"] = token if token
      request
    end
  end

  module SigV4
    def self.sigv4(string_to_sign, aws_secret_access_key, region, date, serviceName)
      k_date    = OpenSSL::HMAC.digest("sha256", "AWS4" + aws_secret_access_key, date)
      k_region  = OpenSSL::HMAC.digest("sha256", k_date, region)
      k_service = OpenSSL::HMAC.digest("sha256", k_region, serviceName)
      k_signing = OpenSSL::HMAC.digest("sha256", k_service, "aws4_request")

      OpenSSL::HMAC.hexdigest("sha256", k_signing, string_to_sign)
    end

    def self.sign(request, params, *args)
      token = args[3] if args[3]
      url = URI.parse(params[:url])
      content = request.body || ""

      algorithm = "AWS4-HMAC-SHA256"
      service = "s3"
      now = Time.now.utc
      time = now.strftime("%Y%m%dT%H%M%SZ")
      date = now.strftime("%Y%m%d")

      body_digest = Digest::SHA256.hexdigest(content)

      request["date"] = now
      request["host"] = url.host
      request["x-amz-date"] = time
      request["x-amz-security-token"] = token if token
      request["x-amz-content-sha256"] = body_digest

      canonical_query_string = url.query || ""
      canonical_headers = request.each_header.sort.map { |k, v| "#{k.downcase}:#{v.gsub(/\s+/, ' ').strip}" }.join("\n") + "\n" # needs extra newline at end
      signed_headers = request.each_name.map(&:downcase).sort.join(";")

      canonical_request = [request.method, url.path, canonical_query_string, canonical_headers, signed_headers, body_digest].join("\n")
      scope = format("%s/%s/%s/%s", date, args[0], service, "aws4_request")
      credential = [args[1], scope].join("/")

      string_to_sign = "#{algorithm}\n#{time}\n#{scope}\n#{Digest::SHA256.hexdigest(canonical_request)}"
      signed_hex = sigv4(string_to_sign, args[2], args[0], date, service)
      auth_string = "#{algorithm} Credential=#{credential}, SignedHeaders=#{signed_headers}, Signature=#{signed_hex}"

      request["Authorization"] = auth_string
      request
    end
  end

  BLOCKSIZE_TO_READ = 1024 * 1000 unless const_defined?(:BLOCKSIZE_TO_READ)

  def self.with_region_detect(region = nil)
    yield(region)
  rescue client::BadRequest => e
    if region.nil?
      region = e.response.headers[:x_amz_region]
      raise if region.nil?
      yield(region)
    else
      raise
    end
  end

  def self.do_request(method, url, bucket, path, *args, public_bucket)
    region = args[3]
    url = build_endpoint_url(bucket, region) if url.nil?

    with_region_detect(region) do |real_region|
      client.reset_before_execution_procs
      client.add_before_execution_proc do |request, params|
        if !public_bucket
          if real_region.nil?
            SigV2.sign(request, bucket, path, args[0], args[1], args[2])
          else
            SigV4.sign(request, params, real_region, args[0], args[1], args[2])
          end
        end
      end
      client::Request.execute(:method => method, :url => "#{url}#{path}", :raw_response => true)
    end
  end

  def self.build_endpoint_url(bucket, region)
    endpoint = if region && region != "us-east-1"
                 "s3-#{region}.amazonaws.com"
               else
                 "s3.amazonaws.com"
               end

    if bucket =~ /^[a-z0-9][a-z0-9-]+[a-z0-9]$/
      "https://#{bucket}.#{endpoint}"
    else
      "https://#{endpoint}/#{bucket}"
    end
  end

  def self.get_md5_from_s3(bucket, url, path, *args, public_bucket)
    if public_bucket
      get_digests_from_s3(bucket, url, path, public_bucket)["md5"]
    else
      get_digests_from_s3(bucket, url, path, args[0], args[1], args[2], args[3], public_bucket)["md5"]
    end
  end

  def self.get_digests_from_headers(headers)
    etag = headers[:etag].gsub('"','')
    digest = headers[:x_amz_meta_digest]
    digests = digest.nil? ? {} : Hash[digest.split(",").map {|a| a.split("=")}]
    return {"md5" => etag}.merge(digests)
  end

  def self.get_digests_from_s3(bucket, url, path, *args, public_bucket,timeout=300,open_timeout=10,retries=5)
    now, auth_string = get_s3_auth("HEAD", bucket,path,aws_access_key_id,aws_secret_access_key, token)
    max_tries = retries + 1
    headers = build_headers(now, auth_string, token)
    saved_exception = nil

    while (max_tries > 0)
      begin

        response = RestClient.head('https://%s.s3.amazonaws.com%s' % [bucket,path], headers)

        etag = response.headers[:etag].gsub('"','')
        digest = response.headers[:x_amz_meta_digest]
        digests = digest.nil? ? {} : Hash[digest.split(",").map {|a| a.split("=")}]

        return {"md5" => etag}.merge(digests)

        rescue => e
           max_tries = max_tries - 1
           saved_exception = e
      end
    end
    raise saved_exception
  end

  def self.validate_download_checksum(response)
    # Default to not checking md5 sum of downloaded objects
    # per http://docs.aws.amazon.com/AmazonS3/latest/API/RESTCommonResponseHeaders.html
    # If an object is created by either the Multipart Upload or Part Copy operation,
    # the ETag is not an MD5 digest, regardless of the method of encryption
    # however, if present, x-amz-meta-digest will contain the digest, so
    # try if we see enough information and verify_md5 is set.
    if response.headers[:x_amz_meta_digest]
      return self.verify_md5_checksum(response.headers[:x_amz_meta_digest_md5].gsub('"',''), response.file.path)
    else
      server_side_encryption_customer_algorithm = response.headers[:x_amz_server_side_encryption_customer_algorithm]
      server_side_encryption = response.headers[:x_amz_server_side_encryption]
      if server_side_encryption_customer_algorithm.nil? and server_side_encryption != "aws:kms"
        return self.verify_md5_checksum(response.headers[:etag].gsub('"',''), response.file.path)
      else
        # If we do not have the x-amz-meta-digest-md5 header, we
        # cannot validate objects encrypted with SSE-C or SSE-KMS,
        # because the ETag will not be the MD5 digest.  Assume it is
        # valid in those cases.
        return true
      end
    end
  end


  def self.get_from_s3(bucket, url, path, aws_access_key_id, aws_secret_access_key, token, public_bucket, verify_md5=false, region = nil)
    response = nil
    retries = 5
    for attempts in 0..retries
      begin
        if public_bucket
          response = do_request("GET", url, bucket, path, public_bucket)
        else
          response = do_request("GET", url, bucket, path, args[0], args[1], args[2], args[3], public_bucket)
        end
        # check the length of the downloaded object,
        # make sure we didn't get nailed by
        # a quirk in Net::HTTP class from the Ruby standard library.
        # Net::HTTP has the behavior (and I would call this a bug) that if the
        # connection gets reset in the middle of transferring the response,
        # it silently truncates the response back to the caller without throwing an exception.
        # ** See https://github.com/ruby/ruby/blob/trunk/lib/net/http/response.rb#L291
        # and https://github.com/ruby/ruby/blob/trunk/lib/net/protocol.rb#L99 .
        # It attempts to read up to Content-Length worth of bytes, but if hits an early EOF,
        # it just returns without throwing an exception (the ignore_eof flag).

        length = response.headers[:content_length].to_i()
        if not length.nil? and response.file.size() != length
          raise "Downloaded object size (#{response.file.size()}) does not match expected content_length (#{length})"
        end

        # default to not checking md5 sum of downloaded objects
        # per http://docs.aws.amazon.com/AmazonS3/latest/API/RESTCommonResponseHeaders.html
        # If an object is created by either the Multipart Upload or Part Copy operation,
        # the ETag is not an MD5 digest, regardless of the method of encryption
        # however, if present, x-amz-meta-digest will contain the digest, so
        # try if we see enough information and verify_md5 is set.
        if verify_md5
          if not self.validate_download_checksum(response)
            raise "Downloaded object has an md5sum which differs from the expected value provided by S3"
          end
        end

        return response
        # break
      rescue client::MovedPermanently, client::Found, client::TemporaryRedirect => e
        uri = URI.parse(e.response.header['location'])
        path = uri.path
        uri.path = ""
        url = uri.to_s
        retry
      rescue => e
        error = e.respond_to?(:response) ? e.response : e
        if attempts < retries
          Chef::Log.warn(error)
          sleep 5
          next
        else
          Chef::Log.fatal(error)
          raise e
        end
        raise e
      end
    end
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
    File.open(decrypt_file, "wb") do |df|
      File.open(file, "rb") do |fi|
        while buffer = fi.read(BLOCKSIZE_TO_READ)
          df.write aes.update(buffer)
        end
      end
      df.write aes.final
    end
    decrypt_file
  end

  def self.verify_sha256_checksum(checksum, file)
    recipe_sha256 = checksum
    local_sha256 = Digest::SHA256.new

    File.open(file, "rb") do |fi|
      while buffer = fi.read(BLOCKSIZE_TO_READ)
        local_sha256.update buffer
      end
    end

    Chef::Log.debug "sha256 provided #{recipe_sha256}"
    Chef::Log.debug "sha256 of local object is #{local_sha256.hexdigest}"

    local_sha256.hexdigest == recipe_sha256
  end

  def self.verify_md5_checksum(checksum, file)
    s3_md5 = checksum
    local_md5 = buffered_md5_checksum(file)

    Chef::Log.debug "md5 of remote object is #{s3_md5}"
    Chef::Log.debug "md5 of local object is #{local_md5.hexdigest}"

    local_md5.hexdigest == s3_md5
  end

  def self.buffered_md5_checksum(file)
    local_md5 = Digest::MD5.new

    # buffer the checksum which should save RAM consumption
    File.open(file, "rb") do |fi|
      while buffer = fi.read(BLOCKSIZE_TO_READ)
        local_md5.update buffer
      end
    end
    local_md5
  end

  def self.verify_etag(etag, file)
    catalog.fetch(file, nil) == etag
  end

  def self.catalog_path
    File.join(Chef::Config[:file_cache_path], 's3_file_etags.json')
  end

  def self.catalog
    File.exist?(catalog_path) ? JSON.parse(IO.read(catalog_path)) : {}
  end

  def self.write_catalog(data)
    File.open(catalog_path, 'w', 0644) { |f| f.write(JSON.dump(data)) }
  end

  def self.client
    require 'rest-client'
    RestClient.proxy = ENV['http_proxy']
    RestClient.proxy = ENV['https_proxy']
    RestClient.proxy = ENV['no_proxy']
    RestClient
  end
end
