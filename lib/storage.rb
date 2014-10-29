require 'mini_magick'
require 'aws-sdk'

module Storage
  class VersionNotExists < StandardError; end
  class NotFoundError < StandardError; end

  SANITIZE_REGEXP = /[^a-zA-Z0-9\.\-\_\[\]]/

  class << self
    attr_accessor :storage_path, :s3_credentials, :bucket_name, :enable_processing

    def setup
      yield self
    end

    def extract_filename(url)
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
    alias_method :extract_basename, :extract_filename
  end
end

if defined?(Rails)
  module Storage
    class Railtie < Rails::Railtie
      initializer "storage.setup_defaults" do
        Storage.storage_path = Rails.root.join(Rails.public_path)
        Storage.bucket_name = Rails.application.engine_name
        Storage.enable_processing = true
      end
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
require "storage/value"

require "storage/serializers/json_serializer"
require "storage/serializers/string_serializer"
