module UploadFixtureHelper
  def fixture_upload(filename)
    File.join(Dir.pwd, "spec", "fixtures", "uploads", filename)
  end
end
