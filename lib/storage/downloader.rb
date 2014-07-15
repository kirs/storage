require 'faraday'
require 'faraday_middleware'

module Storage
  class Downloader
    def initialize(connection = nil)
      @connection ||= self.class.default_connection.call
    end

    def download(url, target)
      uri = URI::parse(url)

      if uri.path.blank?
        raise ArgumentError.new("empty path in #{url}")
      end

      response = @connection.get(url)

      if response.status != 200
        raise NotFoundError.new("failed to download #{url}")
      end

      target.write(response.body)
    ensure
      target.close
    end

    @default_connection = -> {
      Faraday.new do |c|
        c.response :follow_redirects
        c.adapter  :net_http
      end        
    }

    class << self
      attr_accessor :default_connection
    end
  end
end