require 'spec_helper'

describe Storage do
  describe ".extract_basename" do
    let(:url) { "http://i.ebayimg.com/00/s/MTYwMFgxNTQz/z/7LMAAMXQCgpRs1kq/$(KGrHqRHJ!4FBQ!sVjWMBRs1kp8-Lg~~60_1.JPG?set_id=8800005007" }

    it "works" do
      result = described_class.extract_basename(url)
      expect(result).to eq "$(kgrhqrhj!4fbq!svjwmbrs1kp8-lg~~60_1.jpg"
    end
  end
end
