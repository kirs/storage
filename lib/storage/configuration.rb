class Storage::Configuration
  def initialize
    reset!
  end

  def enable_meta
    @meta_enabled = true
  end

  def meta_enabled?
    @meta_enabled
  end

  def self.enable_processing=(val)
    @enable_processing = val
  end

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

  def reset!
    # set defaults

    # key do |klass, field_name, version, filename|
    #   File.join("uploads", klass.name.underscore, model.id.to_s, field_name, version, filename)
    # end
  end
end
