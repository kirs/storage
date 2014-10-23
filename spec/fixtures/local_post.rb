class LocalPost < ActiveRecord::Base
  self.table_name = :posts

  def cover_image
    @cover_image ||= OneMoreLocalStorage.new(self, :cover_image)
  end
end
