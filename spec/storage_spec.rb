require 'spec_helper'

describe Storage do
  describe ".extract_basename" do
    context "first case" do
      let(:url) { "http://i.ebayimg.com/00/s/MTYwMFgxNTQz/z/7LMAAMXQCgpRs1kq/$(KGrHqRHJ!4FBQ!sVjWMBRs1kp8-Lg~~60_1.JPG?set_id=8800005007" }

      it "works" do
        result = described_class.extract_basename(url)
        expect(result).to eq "$(kgrhqrhj!4fbq!svjwmbrs1kp8-lg60_1.jpg"
      end
    end

    context "second case" do
      let(:url) { "http://ebay-social-staging.s3.amazonaws.com/uploads/ebay_item/9/original/$t2ec16zhjguffhzp3vkybs,+l7s-dw~~60_1.jpg" }

      it "works" do
        result = described_class.extract_basename(url)
        expect(result).to eq "$t2ec16zhjguffhzp3vkybsl7s-dw60_1.jpg"
      end
    end
  end
end
