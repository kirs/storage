require 'spec_helper'

describe Storage::UploadedFile do
  let(:dumb_path) { File.join(Dir.pwd, 'spec', "fixtures", "dumb.jpg") }

  context "with local file" do
    it "works" do
      file = described_class.new(::File.new(dumb_path), :local)
      expect(file.local?).to eq true
      expect(file.remote?).to eq false
    end
  end

  context "with remote file" do
    it "works" do
      file = described_class.new(::File.new(dumb_path), :remote)
      expect(file.remote?).to eq true
      expect(file.local?).to eq false
    end
  end

  describe "#unlink" do
    let(:removing_dumb_path) { File.join(Dir.pwd, 'spec', "fixtures", "removing.jpg") }

    before do
      FileUtils.cp(dumb_path, removing_dumb_path)
    end

    it "deletes the file" do
      file = described_class.new(::File.new(removing_dumb_path), :remote)
      file.unlink

      expect(File.exists?(removing_dumb_path)).to eq false
    end
  end
end
