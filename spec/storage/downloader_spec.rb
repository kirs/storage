require 'spec_helper'

describe Storage::Downloader do
  describe ".download" do
    let(:dumb_path) { File.join(Dir.pwd, 'spec', "fixtures", "dumb.jpg") }
    let(:image_url) { "http://putin.vor/1.jpg" }

    context "with valid url" do
      before do
        stub_request(:any, image_url).
          to_return(body: File.new(dumb_path), status: 200)

        @target = Tempfile.new('spec', encoding: 'binary')
      end

      after do
        @target.close
        @target.unlink
      end

      it "works" do
        subject.download(image_url, @target)
        expect(File.size?(@target.path)).to be > 0
      end
    end

    context "with not existing url" do
      before do
        stub_request(:any, image_url).
          to_return(body: "", status: 404)

        @target = Tempfile.new('spec', encoding: 'binary')
      end

      after do
        @target.close
        @target.unlink
      end

      it "works" do
        expect {
          subject.download(image_url, @target)
        }.to raise_error(Storage::NotFoundError)
      end
    end
  end
end