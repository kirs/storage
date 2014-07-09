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

    clear_file_cache
  end

  def remove_remote_copy
    @storage_model.remote.remove_file(remote_key)
    clear_file_cache
  end

  def file
    @file ||= begin
      current_path = local_path

      # if local
      if current_path.exist?
        Storage::UploadedFile.new(::File.open(current_path), :local)
      else # if remote
        tmpfile = Tempfile.new(url.parameterize, encoding: 'binary')
        Storage.download(url(with_protocol: true), tmpfile)
        Storage::UploadedFile.new(tmpfile, :remote)
      end
    end
  end

  def process(original_file = nil)
    return if options.blank? || @storage_model.value.blank?

    cached_original_file = original_file.present?

    if original_file.nil?
      original_file = @storage_model.versions[:original].file
    end

    filename = File.basename(local_path)
    target_file = Tempfile.new(filename, encoding: 'binary')
    process_image(original_file, target_file.path)

    if local_copy_exists?
      FileUtils.rm(local_path)
      FileUtils.cp target_file.path, local_path
    else
      begin
        @storage_model.remote.remove_file(remote_key) # optional, maybe replace
        @storage_model.remote.transfer_from(target_file.path, remote_key)
      end
    end

  ensure
    target_file.try(:unlink)
    if !cached_original_file && original_file.remote?
      original_file.source_file.try(:unlink)
    end
  end

  def transfer_to_remote
    @storage_model.remote.transfer_from(local_path, remote_key)
    remove_local_copy
  end

  def url(with_protocol: false)
    value = @storage_model.value

    return if value.blank?

    key = remote_key
    if local_copy_exists?
      "/#{key}"
    else
      @storage_model.remote.url_for(key, with_protocol: with_protocol)
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

  def process_image(source, target_path)
    image = ::MiniMagick::Image.open(source.path)
    @storage_model.process_image(self, image)
    image.write(target_path)
  end

  def clear_file_cache
    @file = nil
  end
end
