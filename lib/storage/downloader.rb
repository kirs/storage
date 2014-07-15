require 'curb'

module Storage
  class Downloader
    def download(url, target)
      uri = URI::parse(url)

      if uri.path.blank?
        raise ArgumentError.new("empty path in #{url}")
      end

      connection = Curl::Easy.new(uri) do |c|
        c.follow_location = true
      end

      connection.perform

      if connection.status.to_i != 200
        raise NotFoundError.new("failed to download #{url}")
      end

      target.write(connection.body_str)
    ensure
      target.close
    end
  end
end