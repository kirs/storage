class Storage::VersionStorage
  def initialize(version, storage_model)
    @version = version
    @storage_model = storage_model
  end

  def options
    @version.options
  end

  def remove_local_copy
    path = local_path

    if path.exist?
      FileUtils.rm path
      FileUtils.rmdir Storage.storage_path.join(@storage_model.model_uploads_path)
    end
  end

  def remove_remote_copy
    @storage_model.remote.remove_file(remote_key)
  end

  def process
    return if options.blank?

    current_path = local_path
    if current_path.exist?
      process_image(current_path.to_s)
    else
      begin
        tmpfile = Tempfile.new(url.parameterize)
        Storage.download(url, tmpfile)
        process_image(tmpfile.path)
        @storage_model.remote.transfer_from(tmpfile.path, remote_key)
      ensure
        tmpfile.try(:unlink)
      end
    end
  end

  def transfer_to_remote
    @storage_model.remote.transfer_from(local_path, remote_key)
    remove_local_copy
  end

  def url
    value = @storage_model.value

    return if value.blank?

    key = remote_key
    if local_copy_exists?
      "/#{key}"
    else
      @storage_model.remote.url_for(key)
    end
  end

  def remote_key
    File.join(upload_path, @storage_model.value)
  end

  def local_copy_exists?
    local_path.exist?
  end

  def local_path
    Storage.storage_path.join(remote_key)
  end

  def upload_path
    File.join(@storage_model.model_uploads_path, @version.name.to_s)
  end

  private

  def process_image(path)
    image = ::MiniMagick::Image.open(path)

    if options[:resize].present?
      image.resize(options[:resize])
    end
    image.write(path)
  end
end
