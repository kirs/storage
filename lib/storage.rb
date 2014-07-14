require 'mini_magick'
require 'aws-sdk'
require 'open-uri'

module Storage
  class VersionNotExists < StandardError; end

  SANITIZE_REGEXP = /[^a-zA-Z0-9\.\-\_]/
  SEGMENT_SIZE = 32768

  class << self
    attr_accessor :storage_path
    attr_accessor :s3_credentials
    attr_accessor :bucket_name

    def setup
      yield self
    end

    def extract_basename(url)
      uri = URI.parse(url)

      name = uri.path

      extension = File.extname(name)

      name = File.basename(name, extension)
      name = name.gsub("\\", "/") # work-around for IE
      name = name.gsub(SANITIZE_REGEXP, "_")
      name = "_#{name}" if name =~ /\A\.+\z/
      name = "unnamed" if name.size == 0
      name = name.mb_chars


      "#{name}#{extension}".downcase
    end

    def download(url, target)
      uri = URI::parse(url)

      if uri.path.blank?
        raise ArgumentError.new("empty path in #{url}")
      end

      open(uri, 'rb', redirect: true) do |response|
        while not(response.eof?)
          segment = response.read(SEGMENT_SIZE)
          target.write(segment)
        end
      end

    ensure
      target.close
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
require "storage/version"
require "storage/version/opts_validator"
require "storage/version_storage"
require "storage/versions_resolver"
