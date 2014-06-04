describe Storage::Version::OptsValidator do
  context "valid opts" do
    it "validates options" do
      expect {
        described_class.new({ size: "200x100" }).validate
      }.to raise_error Storage::Version::OptsValidator::BadOptionError
    end
  end

  context "invalid opts" do
    it "validates options" do
      expect {
        described_class.new({ resize: "200x100" }).validate
      }.not_to raise_error
    end
  end
end
