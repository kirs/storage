class Storage::Configuration
  def initialize
    reset!
  end

  attr_accessor :meta_enabled, :processing_enabled, :remote_klass, :store_remotely

  def enable_meta
    @meta_enabled = true
  end

  def meta_enabled?
    @meta_enabled
  end

  def self.enable_processing=(val)
    @enable_processing = val
  end

  # def store_remotely
  #   @store_remotely = true
  # end

  # def store_remotely?
  #   !!@store_remotely
  # end

  # def remote_klass
  #   @remote_klass || Storage::Remote
  # end

  # def use_remote(remote_klass)
  #   @remote_klass = remote_klass
  # end

  def reset!
    # set defaults

    # key do |klass, field_name, version, filename|
    #   File.join("uploads", klass.name.underscore, model.id.to_s, field_name, version, filename)
    # end
  end

  def duplicate
    self.class.new.tap do |conf|
      conf.store_remotely = store_remotely
      conf.meta_enabled = meta_enabled
      conf.processing_enabled = processing_enabled
      conf.remote_klass = remote_klass
    end
  end
end
