class OneMoreRemoteStorage < Storage::Model
  version :original
  version :thumb, size: "200x200"
  version :big, size: "300x300"

  use_storage Storage::Storages::RemoteStorage

  def process_image(version, image)
    if version.options[:size].present?
      image.resize(version.options[:size])
    end
  end

  def key(version, filename)
    File.join("uploads", "post", @model.id.to_s, version, filename)
  end
end
