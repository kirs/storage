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

  def meta
    if local_copy_exists?
      { size: File.size(local_path) }
    else
      {}
    end
  end

  # def file
  #   @file ||= begin
  #     current_path = local_path

  #     if current_path.exist?
  #       Storage::UploadedFile.new(::File.open(current_path), :local)
  #     else
  #       tmpfile = Tempfile.new(url.parameterize, encoding: 'binary')
  #       Storage::Downloader.new.download(url(with_protocol: true), tmpfile)
  #       Storage::UploadedFile.new(tmpfile, :remote)
  #     end
  #   end
  # end

  def process(original_file)
    # TODO disable processing in tests
    # return if @storage_model.value.blank?

    filename = File.basename(remote_key)
    extname = File.extname(remote_key)

    target_file = Tempfile.new([filename, extname], encoding: 'binary')

    if Storage.enable_processing
      process_image(original_file, target_file)
    else
      target_file.write(original_file.read(CHUNK_SIZE)) until original_file.eof?
    end

    target_file.rewind
    target_file
  end

  def remote_key
    @storage_model.key(@version.name.to_s, @storage_model.filename)
  end

  # legacy
  def local_path
    if @storage_model.class.storage_klass == Storage::Storages::LocalStorage
      @storage_model.storage.build_local_path(remote_key)
    end
  end

  def meta_enabled?
    @storage_model.meta_enabled?
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

  # def clear_file_cache
  #   @file = nil
  # end

end
