require 'spec_helper'

describe Storage::VersionsResolver do
  let(:versions) {
    [Storage::Version.new(:thumb, {}), Storage::Version.new(:big, {})]
  }
  let(:storage_model) { double(:storage_model) }

  context "with real versions" do
    it "works" do
      resolver = described_class.new(storage_model, versions)

      expect(resolver.big).to eq resolver[:big]
      expect(resolver.big).to be_instance_of(Storage::VersionStorage)

      expect(resolver.thumb).to eq resolver[:thumb]
      expect(resolver.thumb).to be_instance_of(Storage::VersionStorage)
    end
  end

  context "with not existing version" do
    it "throws an error" do
      resolver = described_class.new(storage_model, versions)

      expect {
        resolver[:somewhat]
      }.to raise_error(Storage::VersionNotExists)
    end
  end
end
