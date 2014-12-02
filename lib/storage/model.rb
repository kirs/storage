class Storage::Model
  DEFAULT_VERSION_NAME = :original

  attr_reader :versions, :model, :field_name, :filename

  def self.version(name, options = {})
    @versions ||= []
    @versions << Storage::Version.new(name, options)
  end

  def self.versions
    @versions
  end

  def self.use_storage(storage_klass_or_alias)
    if storage_klass_or_alias.is_a?(Symbol)
      @storage_klass = storage_klass_from_alias(storage_klass_or_alias)
    else
      @storage_klass = storage_klass_or_alias
    end
  end

  def self.storage_klass
    @storage_klass || Storage::Storages::LocalStorage
  end

  def storage
    @storage ||= self.class.storage_klass.new
  end

  def move_to_storage(storage_klass_or_alias)
    # TODO
  end

  def enable_meta
    @meta_enabled = true
  end

  def meta_enabled?
    @meta_enabled
  end

  def initialize(model, field_name)
    unless model.persisted?
      raise ArgumentError.new("model #{model} is not persisted")
    end

    @field_name = field_name.to_sym
    @model = model
    @versions = Storage::VersionsResolver.new(self, self.class.versions)
  end

  def remove
    @versions.each do |version_name, version_object|
      storage.remove(version_object.remote_key)
    end

    @filename = nil
    @model.update!(field_name => nil)
  end

  # legacy
  def local_path
    if self.class.storage_klass == Storage::Storages::LocalStorage
      storage.build_local_path(versions[:original].remote_key)
    end
  end

  def download(original_url, options = {})
    if present?
      remove
    end

    digest = Digest::MD5.hexdigest(original_url)
    target = Tempfile.new(digest, encoding: 'binary')

    Storage::Downloader.new(options).download(original_url, target)

    store(target, filename: original_url)
  ensure
    target.try(:unlink)
  end

  def store(file, filename: nil)
    unless file.respond_to?(:path)
      raise ArgumentError.new("#store receives instance with `path` method")
    end

    original_name = if filename.present?
      filename
    elsif file.respond_to?(:original_filename)
      file.original_filename
    else
      file.path
    end

    @filename = Storage.extract_filename(original_name)

    versions.each do |version_name, version_object|
      if processing_required?
        begin
          result = version_object.process(file)
          storage.save(version_object.remote_key, result)
        ensure
          result.try(:unlink)
        end
      else
        storage.save(version_object.remote_key, file)
      end
    end

    # reprocess

    update_model!
  end

  def filename
    @filename.presence || value.filename
  end

  def value
    Storage::Value.new(model[field_name])
  end
  delegate :present?, :blank?, to: :value

  def url(version_name = DEFAULT_VERSION_NAME)
    if present?
      storage.build_url(@versions[version_name].remote_key)
    else
     default_url(version_name)
   end
  end

  def default_url(version_name)
    "/default/#{self.class.to_s.underscore}/#{version_name}.png"
  end

  # def as_json
  #   if present?
  #     Hash[@versions.map { |version_name, version_object|
  #       [version_name, version_object.url]
  #     }]
  #   else
  #     nil
  #   end
  # end

  def reprocess
    return if blank?

    storage.cached_copy(versions[:original].remote_key) do |file|
      versions.each do |version_name, version_object|
        result = version.process(original_file)
        # replace existing with result
      end
    end
  end

  def key(version, filename)
    File.join("uploads", model.class.name.underscore, model.id.to_s, field_name, version, filename)
  end

  private

  def update_model!
    @model.update!(field_name => serializer.dump)
  end


  def model_column_type
    @model.class.columns_hash[@field_name.to_s].type
  end

  def serializer
    @serializer ||= begin
      serializer_klass.new(self)
    end
  end

  def serializer_klass
    Storage::Serializers.const_get("#{model_column_type.to_s.classify}Serializer")
  end

  class UnknownStorageAliasError < StandardError; end

  def storage_klass_from_alias(klass_alias)
    case klass_alias
    when :remote
      Storage::Storages::RemoteStorage
    when :local
      Storage::Storages::LocalStorage
    else
      raise UnknownStorageAliasError.new("unknown storage alias: #{klass_alias}")
    end
  end

  def processing_required?
    respond_to?(:process_image)
  end
end
