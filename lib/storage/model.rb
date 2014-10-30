class Storage::Model
  DEFAULT_VERSION_NAME = :original

  attr_reader :versions, :model, :field_name, :filename

  module DSL
    def version(name, options = {})
      @versions ||= []
      @versions << Storage::Version.new(name, options)
    end

    def versions
      @versions
    end

    # def self.enable_processing=(val)
    #   @enable_processing = val
    # end

    # def self.enable_processing
    #   if defined?(@enable_processing)
    #     @enable_processing
    #   else
    #     true
    #   end
    # end

    def store_remotely
      @store_remotely = true
    end

    def store_remotely?
      !!@store_remotely
    end

    def remote_klass
      @remote_klass || Storage::Remote
    end

    def use_remote(remote_klass)
      @remote_klass = remote_klass
    end
  end

  extend DSL

  def initialize(model, field_name)
    unless model.persisted?
      raise ArgumentError.new("model #{model} is not persisted")
    end

    @field_name = field_name.to_sym
    @model = model
    @versions = Storage::VersionsResolver.new(self, self.class.versions)
  end

  def skip_remote_storage?
    if defined?(Rails)
      (Rails.env.development? || Rails.env.test?)
    else
      false
    end
  end

  def remove
    @versions.each do |version_name, version_object|
      version_object.remove_local_copy

      if self.class.store_remotely? && !skip_remote_storage?
        version_object.remove_remote_copy
      end
    end

    @filename = nil
    @model.update!(field_name => nil)
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
    save_locally(file)
    reprocess

    if self.class.store_remotely? && !skip_remote_storage?
      transfer_to_remote
    end

    update_model!
  end

  def filename
    @filename.presence || value.filename
  end

  def store_locally(file, filename: nil)
    store(file, filename: filename)
  end

  def transfer_to_remote
    @versions.each do |_, version|
      version.transfer_to_remote
    end
  end

  def local_path
    @versions[DEFAULT_VERSION_NAME].local_path
  end

  def value
    Storage::Value.new(model[field_name])
  end
  delegate :present?, :blank?, to: :value

  def url(version_name = DEFAULT_VERSION_NAME)
    @versions[version_name].url || default_url(version_name)
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

    original_file = versions[:original].file

    @versions.values.each do |version|
      version.process(original_file)
    end

    if original_file.remote?
      original_file.unlink
    end
  end

  def key(version, filename)
    File.join("uploads", model.class.name.underscore, model.id.to_s, field_name, version, filename)
  end

  def process_image(version, image)
    raise NotImplementedError
  end

  private

  def local_copy_exists?
    local_path.exist?
  end

  def update_model!
    @model.update!(field_name => serializer.dump)
  end

  def save_locally(target)
    @versions.each do |_, version_object|
      path = version_object.local_path
      FileUtils.mkdir_p File.dirname(path)
      FileUtils.cp target.path, path
    end

    targets = @versions.map do |_, version_object|
      version_object.local_path.to_s
    end

    FileUtils.chmod 0644, targets
  end

  def model_column_type
    @model.class.columns_hash[@field_name.to_s].type
  end

  def serializer
    @serializer ||= begin
      Storage::Serializers.const_get("#{model_column_type.to_s.classify}Serializer").new(self)
    end
  end
end
