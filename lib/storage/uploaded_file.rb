class Storage::UploadedFile
  attr_reader :source_file, :storage

  def initialize(source_file, storage)
    @source_file = source_file
    @storage = storage
  end

  delegate :path, :extname, :read, :rewind, :eof?, to: :source_file

  def remote?
    @storage == :remote
  end

  def local?
    @storage == :local
  end

  def unlink
    if @source_file.respond_to?(:unlink)
      @source_file.unlink
    else
      File.unlink(@source_file.path)
    end
  end
end
