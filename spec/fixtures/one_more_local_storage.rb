class OneMoreLocalStorage < Storage::Model
  version :original
  version :thumb, size: "200x200"
  version :big, size: "300x300"

  def process_image(version, image)
    if version.options[:size].present?
      image.resize(version.options[:size])
    end
  end

  def model_uploads_path
    File.join("uploads", "post", @model.id.to_s)
  end
end
