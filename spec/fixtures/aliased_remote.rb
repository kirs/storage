class AliasedRemote < Storage::Remote
  def url_for(filename, with_protocol: false)
    "http://storage.evl.ms/#{filename}?ts=123"
  end
end
