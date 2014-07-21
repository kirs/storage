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

    context "with squared brackets case" do
      let(:url) { "http://ebay-social-staging.s3.amazonaws.com/uploads/ebay_item/9/original/abc[].jpg" }

      it "works" do
        result = described_class.extract_basename(url)
        expect(result).to eq "abc__.jpg"
      end
    end    
  end
end
