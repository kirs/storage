class Storage::Remote
  class NoCredentialsError < StandardError
  end

  def transfer_from(path, remote_key)
    remote_target = amazon_bucket.objects[remote_key]
    begin
      remote_target.write(path, acl: acl_mode)
    rescue AWS::S3::Errors::NoSuchBucket
      s3_client.buckets.create(bucket_name)
      retry
    end
  end

  def remove_file(remote_key)
    remote_target = amazon_bucket.objects[remote_key]
    if remote_target.exists?
      remote_target.delete
    end
  end

  def url_for(filename)
    "http://#{bucket_name}.s3.amazonaws.com/#{filename}"
  end

  def amazon_bucket
    s3_client.buckets[bucket_name]
  end

  def s3_client
    if Storage.s3_credentials.blank?
      raise NoCredentialsError
    end

    @s3_client ||= AWS::S3.new(Storage.s3_credentials)
  end

  def bucket_name
    @bucket_name ||= begin
      env_name = Storage.bucket_name.dup
      env_name << "-#{Rails.env}" if defined?(Rails)
      env_name
    end
  end

  def acl_mode
    :public_read
  end
end
