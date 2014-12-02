module Storage::Storages
  class RemoteStorage
    def transfer_to

    end

    def remove(key)
      remote_target = amazon_bucket.objects[key]
      if remote_target.exists?
        remote_target.delete
      end
    end

    def build_url(key, with_protocol: false)
      # return if @storage_model.blank?

      protocol_prefix = if with_protocol
        "http:"
      else
        ""
      end

      "#{protocol_prefix}//#{bucket_name}.s3.amazonaws.com/#{key}"
    end

    def save(key, target)
      path = build_local_path(key)
      FileUtils.mkdir_p File.dirname(path)
      FileUtils.cp target.path, path

      # targets = @versions.map do |_, version_object|
      #   version_object.local_path.to_s
      # end

      FileUtils.chmod 0644, path
    end

    def build_local_path(key)
      Storage.storage_path.join(key)
    end

    def remove_local_copy
      path = local_path

      if path.exist?
        FileUtils.rm path
        FileUtils.rmdir File.dirname(path)
      end

      clear_file_cache
    end

    private

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
      @bucket_name ||= Storage.bucket_name
    end

    def acl_mode
      :public_read
    end


  end
end
