require 'zaru'

class Storage::Model
  DEFAULT_VERSION_NAME = :original

  class_attribute :versions, instance_accessor: false

  attr_reader :versions

  def self.version(name, options = {})
    Storage::OptsValidator.new(options).validate

    self.versions ||= {}
    self.versions[name] = Storage::Version.new(name, options)
  end

  def initialize(model, field_name)
    unless model.persisted?
      raise ArgumentError.new("model #{model} has no id yet")
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

    @basename = Storage.extract_basename(original_url)

    download_original(original_url, target)

    save_locally(target)
    process_locally

    if remote_storage_enabled?
      transfer_to_remote
    end

    update_model!
  ensure
    target.unlink if target.present?
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
    @versions.each do |version_name, version_object|
      next if version_object.options.blank?

      current_path = version_object.local_path
      if current_path.exist?
        process_version(version_object, current_path.to_s)
      else
        begin
          url = url(version_name)
          tmpfile = Tempfile.new(url.parameterize)
          download_original(url, tmpfile)
          process_version(version_object, tmpfile.path)
          remote.transfer_from(tmpfile.path, version_object.remote_key)
        ensure
          tmpfile.try(:unlink)
        end
      end
    end
  end

  def model_uploads_path
    File.join("uploads", @model.class.name.underscore, @model.id.to_s)
  end

  def remote
    @remote ||= ::Storage::Remote.new
  end

  private

  def process_locally
    @versions.each do |version_name, version_object|
      next if version_object.options.blank?

      current_path = version_object.local_path
      process_version(version_object, current_path.to_s)
    end
  end

  def process_version(version_object, path)
    image = ::MiniMagick::Image.open(path)

    if version_object.options[:resize].present?
      image.resize(version_object.options[:resize])
    end
    image.write(path)
  end

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

  def download_original(url, target)
    uri = URI::parse(url)

    if uri.path.blank?
      raise ArgumentError.new("empty path in #{url}")
    end

    Net::HTTP.get_response(uri) do |response|
      response.read_body do |segment|
        target.write(segment)
      end
    end

  ensure
    target.close
  end
end
