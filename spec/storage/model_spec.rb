require 'spec_helper'

class OneMoreStorage < Storage::Model
  version :original
  version :thumb, resize: "200x200"
  version :big, resize: "300x300"
end

class Post < ActiveRecord::Base
  def cover_image
    @cover_image ||= OneMoreStorage.new(self, :cover_image)
  end
end

describe Storage::Model do
  before do
    cleanup_post_uploads
  end

  after do
    cleanup_post_uploads
  end

  before(:all) do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.create_table "posts", temporary: true do |t|
        t.string :cover_image
      end
    end
  end

  after(:all) do
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.drop_table "posts"
    end
  end

  describe "#storage_path" do
    before do
      @original_storage_path = Storage.storage_path
    end

    after do
      Storage.storage_path = @original_storage_path
    end

    it "works" do
      expect(@original_storage_path).to be_present#eq Rails.root.join("public")

      somewhere_else = File.join("tmp", "somewhere", "else")
      Storage.storage_path = somewhere_else
      expect(Storage.storage_path).to eq somewhere_else
    end
  end

  describe "initializer" do
    context "with persisted model" do
      it "returns Storage" do
        post = Post.create!
        expect(post.cover_image).to be_instance_of(OneMoreStorage)
      end
    end

    context "with new model" do
      it "returns Storage" do
        post = Post.new
        expect {
          post.cover_image
        }.to raise_error ArgumentError
      end
    end
  end

  describe "#download" do
    let(:dumb_path) {
      File.join(Dir.pwd, 'spec', "fixtures", "dumb.jpg")
    }
    let(:image_url) { "http://putin.vor/1.jpg" }

    context "local upload" do
      context "valid filename" do
        before do
          stub_request(:any, image_url).
            to_return(body: File.new(dumb_path), status: 200)

          allow_any_instance_of(described_class).to receive(:remote_storage_enabled?).and_return(false)
        end

        it "works" do
          post = Post.create!
          expect(post.cover_image.present?).to eq false

          post.cover_image.download(image_url)

          expect(post[:cover_image]).to eq '1.jpg'

          expect(post.cover_image.present?).to eq true

          expect(post.cover_image.local_path.exist?).to eq true

          OneMoreStorage.versions.each do |version, options|
            version_path = post.cover_image.local_path_for(version)
            expect(version_path.exist?).to eq true
          end
        end
      end

      context "valid filename" do
        let(:image_url) { "http://i.ebayimg.com/00/s/MTYwMFgxNTQz/z/7LMAAMXQCgpRs1kq/$(KGrHqRHJ!4FBQ!sVjWMBRs1kp8-Lg~~60_1.JPG?set_id=8800005007" }

        before do
          stub_request(:any, "http://i.ebayimg.com/00/s/MTYwMFgxNTQz/z/7LMAAMXQCgpRs1kq/$(KGrHqRHJ!4FBQ!sVjWMBRs1kp8-Lg~~60_1.JPG").
            to_return(body: File.new(dumb_path), status: 200)

          allow_any_instance_of(described_class).to receive(:remote_storage_enabled?).and_return(false)
        end

        it "works" do
          post = Post.create!
          expect(post.cover_image.present?).to eq false

          post.cover_image.download(image_url)

          expect(post[:cover_image]).to eq "$(kgrhqrhj!4fbq!svjwmbrs1kp8-lg~~60_1.jpg"

          expect(post.cover_image.present?).to eq true

          expect(post.cover_image.local_path.exist?).to eq true

          OneMoreStorage.versions.each do |version, options|
            version_path = post.cover_image.local_path_for(version)
            expect(version_path.exist?).to eq true
          end
        end
      end
    end

    context "remote upload" do
      before do
        allow_any_instance_of(described_class).to receive(:remote_storage_enabled?).and_return(true)

        stub_request(:any, image_url).
          to_return(body: File.new(dumb_path), status: 200)
      end

      it "works" do
        post = Post.create!

        stub_request(:put, "https://ebay-social.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/1.jpg")
        stub_request(:put, "https://ebay-social.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg")
        stub_request(:put, "https://ebay-social.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg")

        expect(post.cover_image.present?).to eq false

        post.cover_image.download(image_url)

        post.reload

        expect(post[:cover_image]).to eq '1.jpg'
        expect(post.cover_image.present?).to eq true

        expect(post.cover_image.url).to eq "http://ebay-social.s3.amazonaws.com/uploads/post/#{post.id}/original/1.jpg"
      end
    end
  end

  describe "#url" do

    let(:filename) { '1.jpg' }

    context "local upload" do
      it "works" do
        post = Post.create!(cover_image: filename)

        allow(post.cover_image).to receive(:local_copy_exists?).and_return(true)
        expect(post.cover_image.url).to eq "/uploads/post/#{post.id}/original/#{filename}"
      end
    end

    context "remote upload" do
      it "works" do
        bucket_name = "ebay-social"
        post = Post.create!(cover_image: filename)
        expect(post.cover_image.url).to eq "http://#{bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/original/#{filename}"
        expect(post.cover_image.url(:big)).to eq "http://#{bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/big/#{filename}"
      end
    end
  end

  def cleanup_post_uploads
    FileUtils.rm_rf(Storage.storage_path)
  end
end
