require 'spec_helper'

describe Storage::VersionStorage do
  describe "#name" do
    let(:version) { double(name: "123", options: {foo: "var"}) }
    let(:model) { double }

    it "works" do
      version_storage = described_class.new(version, model)
      expect(version_storage.name).to eq version.name
      expect(version_storage.options).to eq version.options
    end
  end

  describe "#url" do
    context "with local file" do
      let(:model) {
        double(value: "1.jpg", model_uploads_path: "uploads/public")
      }
      let(:version) {
        double(name: "my_version", options: {foo: "var"})
      }

      it "works" do
        version_storage = described_class.new(version, model)
        allow(version_storage).to receive(:local_copy_exists?).and_return(true)
        expect(version_storage.url).to eq '/uploads/public/my_version/1.jpg'
      end
    end
  end
end
