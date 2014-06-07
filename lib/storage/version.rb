class Storage::Version
  attr_accessor :name, :options

  def initialize(name, options)
    # OptsValidator.new(options).validate

    @name = name
    @options = options
  end
end
