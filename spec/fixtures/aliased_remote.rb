class AliasedRemote < Storage::Storages::RemoteStorage
  def build_url(key, with_protocol: false)
    "http://storage.evl.ms/#{key}?ts=123"
  end
end
