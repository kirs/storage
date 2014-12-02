require 'httparty'

module Storage
  # HTTParty is used to follow https redirects
  class Downloader
    def initialize(options = nil)
      @options = options || self.class.options || {}
    end

    def download(url, target, options = {})
      url = URI::escape(url, UNSAFE_URL_CHARS)
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

  UNSAFE_URL_CHARS = '<>{}|\\^~[]`#'
end
