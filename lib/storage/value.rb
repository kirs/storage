class Storage::Value
  attr_reader :filename, :versions

  def initialize(data)
    return if data.nil?

    if data.is_a?(String)
      @filename = data
      @versions = {}
    elsif data.is_a?(Hash)
      data = data.with_indifferent_access
      @filename = data[:filename]
      @versions = data[:versions]
    else
      raise ArgumentError.new("unknown input")
    end
  end

  def present?
    filename.present?
  end

  def blank?
    filename.blank?
  end
end
