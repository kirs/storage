class Storage::Model
  DEFAULT_VERSION_NAME = :original

  class_attribute :versions, instance_accessor: false

  attr_reader :versions

  def self.version(name, options = {})
    self.versions ||= []
    self.versions << Storage::Version.new(name, options)
  end

  def self.store_remotely
    @store_remotely = true
  end

  def self.store_remotely?
    !!@store_remotely
  end

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

    @basename = nil
    update_model!
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

    @basename = Storage.extract_basename(original_name)
    save_locally(file)
    reprocess

    if self.class.store_remotely? && !skip_remote_storage?
      transfer_to_remote
    end

    update_model!
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
    @basename.presence || @model[@field_name]
  end

  def url(version_name = DEFAULT_VERSION_NAME)
    @versions[version_name].url || default_url(version_name)
  end

  def present?
    value.present?
  end

  def default_url(version_name)
    "/default/#{self.class.to_s.underscore}/#{version_name}.png"
  end

  def blank?
    !present?
  end

  def as_json
    if present?
      Hash[@versions.map { |version_name, version_object|
        [version_name, version_object.url]
      }]
    else
      nil
    end
  end

  def reprocess
    if blank?
      return
    end

    original_file = versions[:original].file

    @versions.values.each do |version|
      version.process(original_file)
    end

    if original_file.remote?
      original_file.unlink
    end
  end

  def model_uploads_path
    File.join("uploads", @model.class.name.underscore, @model.id.to_s)
  end

  def remote
    @remote ||= remote_klass.new
  end

  def remote_klass
    ::Storage::Remote
  end

  def process_image(version, image)
    raise NotImplementedError
  end

  private

  def local_copy_exists?
    local_path.exist?
  end

  def update_model!
    @model.update!(@field_name => @basename)
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
end
