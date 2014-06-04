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
  let(:dumb_path) {
    File.join(Dir.pwd, 'spec', "fixtures", "dumb.jpg")
  }

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
      expect(@original_storage_path).to be_present

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

          post.cover_image.versions.each do |_, version|
            expect(version.local_path.exist?).to eq true
          end
        end
      end

      context "valid filename" do
        let(:image_url) { "http://i.ebayimg.com/00/s/MTYwMFgxNTQz/z/7LMAAMXQCgpRs1kq/$(KGrHqRHJ!4FBQ!sVjWMBRs1kp8-Lg~~60_1.JPG?set_id=8800005007" }

        before do
          stub_request(:get, image_url).
            to_return(body: File.new(dumb_path), status: 200)

          allow_any_instance_of(described_class).to receive(:remote_storage_enabled?).and_return(false)

          allow(Storage).to receive(:extract_basename).and_return("1.jpg")
        end

        it "works" do
          post = Post.create!
          expect(post.cover_image.present?).to eq false

          post.cover_image.download(image_url)

          expect(post[:cover_image]).to eq "1.jpg"

          expect(post.cover_image.present?).to eq true

          expect(post.cover_image.local_path.exist?).to eq true

          post.cover_image.versions.each do |_, version|
            expect(version.local_path.exist?).to eq true
          end
        end
      end

      context "already downloaded" do
        let(:another_image_url) { "http://i.ebayimg.com/something_else.jpg" }

        before do
          stub_request(:any, image_url).
            to_return(body: File.new(dumb_path), status: 200)

          stub_request(:any, another_image_url).
            to_return(body: File.new(dumb_path), status: 200)

          allow_any_instance_of(described_class).to receive(:remote_storage_enabled?).and_return(false)
        end

        it "removes old picture" do
          post = Post.create!
          expect(post.cover_image.present?).to eq false

          post.cover_image.download(image_url)

          expect(post.cover_image.present?).to eq true

          old_local_path = post.cover_image.local_path
          expect(old_local_path.exist?).to eq true

          post.cover_image.download(another_image_url)
          expect(post.cover_image.present?).to eq true

          expect(old_local_path.exist?).to eq false
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

        stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/1.jpg")
        stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg")
        stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg")

        expect(post.cover_image.present?).to eq false

        post.cover_image.download(image_url)

        post.reload

        expect(post[:cover_image]).to eq '1.jpg'
        expect(post.cover_image.present?).to eq true

        expect(post.cover_image.url).to eq "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/original/1.jpg"
      end

      describe "remove" do
        let(:post) { Post.create!(cover_image: '1.jpg') }
        before do
          stub_request(:head, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/1.jpg").to_return(status: 200)
          stub_request(:head, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg").to_return(status: 200)
          stub_request(:head, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg").to_return(status: 200)
        end

        it "can be removed" do
          expect(post.cover_image.present?).to eq true

          stub_request(:delete, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/1.jpg")
          stub_request(:delete, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg")
          stub_request(:delete, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg")

          post.cover_image.remove

          expect(a_request(:delete, "https://teamnavalny.s3-eu-west-1.amazonaws.com/uploads/post/1/original/1.jpg")).to have_been_made.once

          expect(post.cover_image.present?).to eq false
        end
      end
    end
  end

  describe "#url" do
    let(:filename) { '1.jpg' }

    context "not existing version" do
      it "throws exception" do
        post = Post.create!(cover_image: filename)

        expect {
          post.cover_image.url(:somewhat)
        }.to raise_error(Storage::VersionNotExists)
      end
    end

    context "local upload" do
      it "works" do
        post = Post.create!(cover_image: filename)

        allow(post.cover_image.versions[:original]).to receive(:local_copy_exists?).and_return(true)
        expect(post.cover_image.url).to eq "/uploads/post/#{post.id}/original/#{filename}"
      end
    end

    context "remote upload" do
      it "works" do
        post = Post.create!(cover_image: filename)
        expect(post.cover_image.url).to eq "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/original/#{filename}"
        expect(post.cover_image.url(:big)).to eq "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/big/#{filename}"
      end
    end
  end

  describe "#as_json" do
    let(:filename) { '1.jpg' }

    context "file present" do
      it "works" do
        post = Post.create!(cover_image: filename)

        urls = {
          original: "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/1/original/1.jpg",
          thumb: "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/1/thumb/1.jpg",
          big: "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/1/big/1.jpg"
        }

        expect(post.cover_image.as_json).to eq urls
      end
    end

    context "file absent" do
      it "works" do
        post = Post.create!

        expect(post.cover_image.as_json).to eq nil
      end
    end
  end

  describe "#reprocess" do
    let(:image_url) { "http://putin.vor/1.jpg" }

    context "with remote storage" do
      before do
        allow_any_instance_of(described_class).to receive(:remote_storage_enabled?).and_return(true)

        stub_request(:any, image_url).
          to_return(body: File.new(dumb_path), status: 200)
      end

      it "works" do
        post = Post.create!(cover_image: '1.jpg')

        expect(post.cover_image.present?).to eq true

        stub_request(:get, "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/original/1.jpg").to_return(body: File.new(dumb_path), status: 200)
        stub_request(:get, "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg").to_return(body: File.new(dumb_path), status: 200)
        stub_request(:get, "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/big/1.jpg").to_return(body: File.new(dumb_path), status: 200)

        put_thumb = stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg")
        put_big = stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg")

        post.cover_image.reprocess

        expect(put_thumb).to have_been_made.times(1)
        expect(put_big).to have_been_made.times(1)
      end
    end
  end

  describe "#versions" do
    it "present" do
      post = Post.create!(cover_image: '1.jpg')
      versions = post.cover_image.versions
      expect(versions).to be_present

      expect(versions[:original]).to be_instance_of(Storage::VersionStorage)
      expect(versions[:big]).to be_instance_of(Storage::VersionStorage)
      expect(versions[:thumb]).to be_instance_of(Storage::VersionStorage)
    end
  end

  def cleanup_post_uploads
    FileUtils.rm_rf(Storage.storage_path)
  end
end
