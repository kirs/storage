require 'mini_magick'
require 'aws-sdk'

module Storage
  class << self
    attr_accessor :storage_path
    attr_accessor :s3_credentials
    attr_accessor :bucket_name

    def setup
      yield self
    end

    def extract_basename(url)
      uri = URI.parse(url)
      filename = uri.path
      @extension = File.extname(filename)
      @basename = Zaru.new(File.basename(filename, @extension)).sanitize
      ["~", ",", "+"].each do |symb|
        @basename = @basename.gsub(symb, "")
      end
      "#{@basename}#{@extension}".downcase
    end
  end
end

if defined?(Rails)
  module Storage
    class Railtie < Rails::Railtie
      initializer "storage.setup_paths" do
        Storage.storage_path = Rails.root.join(Rails.public_path)
        Storage.bucket_name = Rails.application.engine_name
      end

      # initializer "carrierwave.active_record" do
      #   ActiveSupport.on_load :active_record do
      #     require 'carrierwave/orm/activerecord'
      #   end
      # end
    end
  end

end

require "storage/model"
require "storage/opts_validator"
require "storage/remote"
require "storage/version"
