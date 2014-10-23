class RemotePost < ActiveRecord::Base
  self.table_name = :posts

  def cover_image
    @cover_image ||= OneMoreRemoteStorage.new(self, :cover_image)
  end
end
