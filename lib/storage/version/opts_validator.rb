class Storage::Version::OptsValidator
  class BadOptionError < StandardError
  end

  ALLOWED_KEYS = %i{resize}

  def initialize(version_options)
    @version_options = version_options
  end

  def validate
    @version_options.keys.each do |key|
      next if ALLOWED_KEYS.include?(key)

      raise BadOptionError.new("Option #{key} is not supported. Supported options: #{ALLOWED_KEYS}")
    end
  end
end
