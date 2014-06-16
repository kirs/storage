class Storage::Model
  DEFAULT_VERSION_NAME = :original

  class_attribute :versions, instance_accessor: false

  attr_reader :versions

  def self.version(name, options = {})
    self.versions ||= []
    self.versions << Storage::Version.new(name, options)
  end

  def initialize(model, field_name)
    unless model.persisted?
      raise ArgumentError.new("model #{model} is not persisted")
    end

    @field_name = field_name.to_sym
    @model = model
    @versions = Storage::VersionsResolver.new(self, self.class.versions)
  end

  def remote_storage_enabled?
    if defined?(Rails)
      !(Rails.env.development? || Rails.env.test?)
    else
      false
    end
  end

  def remove
    @versions.each do |version_name, version_object|
      version_object.remove_local_copy

      if remote_storage_enabled?
        version_object.remove_remote_copy
      end
    end

    @basename = nil
    update_model!
  end

  def download(original_url)
    if present?
      remove
    end

    digest = Digest::MD5.hexdigest(original_url)
    target = Tempfile.new(digest, encoding: 'binary')

    Storage.download(original_url, target)

    store(target, original_url)
  ensure
    target.try(:unlink)
  end

  def store(file, name = nil)
    unless file.is_a?(File) || file.is_a?(Tempfile)
      raise ArgumentError.new("#store receives instance of File or Tempfile")
    end

    @basename = Storage.extract_basename(name.presence || file.path)
    save_locally(file)
    reprocess

    if remote_storage_enabled?
      transfer_to_remote
    end

    update_model!
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
    @versions[version_name].url
  end

  def present?
    url.present?
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
    return unless present?

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
    @remote ||= ::Storage::Remote.new
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
