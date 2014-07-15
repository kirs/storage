require 'httparty'

module Storage
  class Downloader
    def initialize(options = nil)
      @options = options || self.class.options || {}
    end

    def download(url, target, options = {})
      uri = URI::parse(url)

      if uri.path.blank?
        raise ArgumentError.new("empty path in #{url}")
      end

      response = HTTParty.get(url, @options)

      if response.code != 200
        raise NotFoundError.new("failed to download #{url}")
      end

      target.write(response.body)
    ensure
      target.close
    end

    class << self
      attr_accessor :options
    end
    @options = { follow_redirects: true }    
  end  
end