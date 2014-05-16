require 'zaru'

class Storage::Model
  DEFAULT_VERSION_NAME = :original

  class_attribute :versions, instance_accessor: false

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
  end

  def remote_storage_enabled?
    if defined?(Rails)
      !(Rails.env.development? || Rails.env.test?)
    else
      false
    end
  end

  def download(original_url)
    # remove previous
    if present?
      self.class.versions.each do |version_name, _|
        remove_local_copy(version_name)
      end
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

    update_model
  ensure
    target.unlink if target.present?
  end

  def transfer_to_remote
    self.class.versions.each do |version_name, options|
      path = local_path_for(version_name.to_s)

      remote.transfer_from(path, remote_key_for(version_name))
      remove_local_copy(version_name)
    end
  end

  def local_path_for(version_name)
    Storage.storage_path.join(remote_key_for(version_name.to_s))
  end

  def local_path
    local_path_for(DEFAULT_VERSION_NAME)
  end

  def url(version_name = DEFAULT_VERSION_NAME)
    value = @model[@field_name]

    return if value.blank?

    key = remote_key_for(version_name)
    if local_copy_exists?
      "/#{key}"
    else
      remote.url_for(key)
    end
  end

  def present?
    url.present?
  end

  def blank?
    !present?
  end

  private

  def process_locally
    self.class.versions.each do |version_name, version_object|
      next if version_object.options.blank?

      current_path = local_path_for(version_name)
      image = ::MiniMagick::Image.open(current_path.to_s)

      if version_object.options[:resize].present?
        image.resize(version_object.options[:resize])
      end
      image.write(current_path)
    end
  end

  def local_copy_exists?
    local_path.exist?
  end

  def remove_local_copy(version_name)
    FileUtils.rm local_path_for(version_name)
    FileUtils.rmdir Storage.storage_path.join(model_uploads_path)
  end

  def update_model
    @model.update!(@field_name => @basename)
  end

  def remote
    @remote ||= ::Storage::Remote.new
  end

  def upload_path_for(version_name)
    File.join(model_uploads_path, version_name.to_s)
  end

  def remote_key_for(version_name)
    File.join(upload_path_for(version_name.to_s), @basename.presence || @model[@field_name])
  end

  def model_uploads_path
    File.join("uploads", @model.class.name.underscore, @model.id.to_s)
  end

  def save_locally(target)
    self.class.versions.each do |version_name, version_object|
      path = local_path_for(version_name)
      FileUtils.mkdir_p File.dirname(path)
      FileUtils.cp target.path, path
    end

    targets = self.class.versions.map do |version_name, version_object|
      local_path_for(version_name).to_s
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
