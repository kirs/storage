class Storage::VersionStorage
  CHUNK_SIZE = 2**16

  def initialize(version, storage_model)
    @version = version
    @storage_model = storage_model
  end

  def name
    @version.name
  end

  def options
    @version.options
  end

  def storage_type
    if local_copy_exists?
      :local
    else
      :remote
    end
  end

  def meta
    if local_copy_exists?
      { size: File.size(local_path) }
    else
      {}
    end
  end

  def remove_local_copy
    path = local_path

    if path.exist?
      FileUtils.rm path
      FileUtils.rmdir File.dirname(path)
    end

    clear_file_cache
  end

  def remove_remote_copy
    remote.remove_file(remote_key)
    clear_file_cache
  end

  def file
    @file ||= begin
      current_path = local_path

      if current_path.exist?
        Storage::UploadedFile.new(::File.open(current_path), :local)
      else
        tmpfile = Tempfile.new(url.parameterize, encoding: 'binary')
        Storage::Downloader.new.download(url(with_protocol: true), tmpfile)
        Storage::UploadedFile.new(tmpfile, :remote)
      end
    end
  end

  def process(original_file = nil)
    # TODO disable processing in tests
    return if @storage_model.value.blank?

    cached_original_file = original_file.present?

    if original_file.nil?
      original_file = @storage_model.versions[:original].file
    end

    filename = File.basename(local_path)
    extname = File.extname(local_path)

    target_file = Tempfile.new([filename, extname], encoding: 'binary')
    # if @storage_model.class.enable_processing &&
    if Storage.enable_processing
      process_image(original_file, target_file)
    else
      target_file.write(original_file.read(CHUNK_SIZE)) until original_file.eof?
    end

    # original_file.rewind
    target_file.rewind

    if local_copy_exists?
      FileUtils.rm(local_path)
      FileUtils.cp target_file.path, local_path
    else
      remote.remove_file(remote_key) # optional, maybe replace
      remote.transfer_from(target_file, remote_key)
    end

  ensure
    target_file.try(:unlink)
    if !cached_original_file && original_file.remote?
      original_file.source_file.try(:unlink)
    end
  end

  def transfer_to_remote
    remote.transfer_from(local_path, remote_key)
    remove_local_copy
  end

  def url(with_protocol: false)
    return if @storage_model.blank?

    key = remote_key
    if local_copy_exists?
      "/#{key}"
    else
      remote.url_for(key, with_protocol: with_protocol)
    end
  end

  def remote_key
    @storage_model.key(@version.name.to_s, @storage_model.filename)
  end

  def local_copy_exists?
    local_path.exist?
  end

  def local_path
    Storage.storage_path.join(remote_key)
  end

  def meta_enabled?
    @storage_model.class.configuration.meta_enabled?
  end

  private

  def process_image(source, target)
    image = ::MiniMagick::Image.open(source.path)
    result = @storage_model.process_image(self, image)
    if result.is_a?(MiniMagick::Image)
      image = result
    end

    image.write(target)
  end

  def clear_file_cache
    @file = nil
  end

  def remote
    @remote ||= @storage_model.class.configuration.remote_klass.new
  end
end
