require 'mini_magick'
require 'aws-sdk'

module Storage
  class VersionNotExists < StandardError; end
  class NotFoundError < StandardError; end

  SANITIZE_REGEXP = /[^a-zA-Z0-9\.\-\_\[\]]/

  class << self
    attr_accessor :storage_path
    attr_accessor :s3_credentials
    attr_accessor :bucket_name

    def setup
      yield self
    end

    def extract_basename(url)
      begin
        uri = URI.parse(url.gsub(/[\[\]]/, '_'))
        name = uri.path
      rescue URI::InvalidURIError
        name = url
      end

      extension = File.extname(name)

      name = File.basename(name, extension)
      name = name.gsub("\\", "/") # work-around for IE
      name = name.gsub(SANITIZE_REGEXP, "_")
      name = "_#{name}" if name =~ /\A\.+\z/
      name = "unnamed" if name.size == 0
      name = name.mb_chars

      "#{name}#{extension}".downcase
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
require "storage/uploaded_file"
require "storage/remote"
require "storage/downloader"
require "storage/version"
require "storage/version/opts_validator"
require "storage/version_storage"
require "storage/versions_resolver"
