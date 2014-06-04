class Storage::VersionsResolver
  attr_reader :versions

  def initialize(storage_model, versions)
    @versions = Hash[versions.map { |v|
      [v.name, Storage::VersionStorage.new(v, storage_model)]
    }]
  end

  def [](val)
    val = val.to_sym
    if @versions.has_key?(val)
      @versions[val]
    else
      raise Storage::VersionNotExists
    end
  end

  def method_missing(method_sym, *arguments, &block)
    if @versions.respond_to?(method_sym)
      @versions.send(method_sym, *arguments, &block)
    else
      super
    end
  end

  def respond_to?(method_sym)
    @versions.respond_to?(method_sym) || super
  end
end
