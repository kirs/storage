module Storage::Storages
  class LocalStorage
    def transfer_to

    end

    def remove(key)
      path = build_local_path(key)
      File.unlink(path)
    end

    def build_url(key, with_protocol: false)
      "/#{key}"
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
  end
end
