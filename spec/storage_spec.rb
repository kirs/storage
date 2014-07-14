require 'spec_helper'

describe Storage do
  describe ".extract_basename" do
    context "with query" do
      let(:url) { "http://i.ebayimg.com/00/s/MTYwMFgxNTQz/z/7LMAAMXQCgpRs1kq/$(KGrHqRHJ!4FBQ!sVjWMBRs1kp8-Lg~~60_1.JPG?set_id=8800005007" }

      it "works" do
        result = described_class.extract_basename(url)
        expect(result).to eq "__kgrhqrhj_4fbq_svjwmbrs1kp8-lg__60_1.jpg"
      end
    end

    context "with special chars" do
      let(:url) { "http://ebay-social-staging.s3.amazonaws.com/uploads/ebay_item/9/original/$t2ec16zhjguffhzp3vkybs,+l7s-dw~~60_1.jpg" }

      it "works" do
        result = described_class.extract_basename(url)
        expect(result).to eq "_t2ec16zhjguffhzp3vkybs__l7s-dw__60_1.jpg"
      end
    end

    context "with empty case" do
      let(:url) { "http://ebay-social-staging.s3.amazonaws.com/uploads/ebay_item/9/original/$,~~.jpg" }

      it "works" do
        result = described_class.extract_basename(url)
        expect(result).to eq "____.jpg"
      end
    end
  end

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
        described_class.download(image_url, @target)
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
          described_class.download(image_url, @target)
        }.to raise_error(Storage::NotFoundError)
      end
    end
  end
end
