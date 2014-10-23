require 'spec_helper'

require_relative '../fixtures/local_post'
require_relative '../fixtures/one_more_local_storage'

require_relative '../fixtures/remote_post'
require_relative '../fixtures/one_more_remote_storage'

describe Storage::Model do
  let(:dumb_path) { fixture_upload("dumb.jpg") }

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
        post = LocalPost.create!
        expect(post.cover_image).to be_instance_of(OneMoreLocalStorage)
      end
    end

    context "with new model" do
      it "returns Storage" do
        post = LocalPost.new
        expect {
          post.cover_image
        }.to raise_error ArgumentError
      end
    end
  end

  describe "#store" do
    context "with bad object instead of file" do
      context "with String" do
        it "throws an error" do
          post = LocalPost.create!

          expect {
            post.cover_image.store("/etc/passwd")
          }.to raise_error(ArgumentError)
        end
      end

      context "with Pathname" do
        it "throws an error" do
          post = LocalPost.create!

          expect {
            post.cover_image.store(Pathname.new("/etc/passwd"))
          }.to raise_error(ArgumentError)
        end
      end
    end

    context "with local upload" do
      context "with Rack::UploadedFile instance" do
        context "with default name" do
          it "stores the file" do
            post = LocalPost.create!

            dumb = Rack::Test::UploadedFile.new(dumb_path)
            post.cover_image.store(dumb)

            expect(post.cover_image).to be_present
            expect(post.cover_image.local_path.exist?).to eq true

            expect(post[:cover_image]).to eq 'dumb.jpg'
          end
        end

        context "with custom name" do
          it "stores the file" do
            post = LocalPost.create!

            dumb = Rack::Test::UploadedFile.new(dumb_path)
            post.cover_image.store(dumb, filename: "not_a_dumb.jpg")

            expect(post.cover_image).to be_present
            expect(post.cover_image.local_path.exist?).to eq true

            expect(post[:cover_image]).to eq 'not_a_dumb.jpg'
          end
        end
      end

      context "with File instance" do
        context "with clear filename" do
          it "stores the file" do
            post = LocalPost.create!

            dumb = File.open(dumb_path)
            post.cover_image.store(dumb)

            expect(post.cover_image).to be_present
            expect(post.cover_image.local_path.exist?).to eq true

            expect(post[:cover_image]).to eq 'dumb.jpg'
          end
        end

        context "with irregular filename" do
          it "cleanes up filename" do
            post = LocalPost.create!

            allow(Storage).to receive(:extract_basename).and_return("1.jpg")

            dumb = File.open(dumb_path)
            post.cover_image.store(dumb)

            expect(post.cover_image).to be_present
            expect(post[:cover_image]).to eq '1.jpg'
          end
        end
      end
    end

    context "with remote upload" do
      context "with clear filename" do
        let(:post) { RemotePost.create! }

        before do
          stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/dumb.jpg")
          stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/dumb.jpg")
          stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/dumb.jpg")
        end

        it "stores the file" do
          dumb = File.open(dumb_path)
          post.cover_image.store(dumb)

          expect(post.cover_image).to be_present
          expect(post.cover_image.local_path.exist?).to eq false

          expect(post.cover_image.url).to eq "//#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/original/dumb.jpg"

          expect(post[:cover_image]).to eq 'dumb.jpg'
        end
      end
    end
  end

  describe "#download" do
    let(:image_url) { "http://putin.vor/1.jpg" }

    context "local upload" do
      context "with clear filename" do
        before do
          stub_request(:any, image_url).
            to_return(body: File.new(dumb_path), status: 200)

        end

        it "works" do
          post = LocalPost.create!
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

      context "with irregular filename" do
        let(:image_url) { "http://i.ebayimg.com/00/s/MTYwMFgxNTQz/z/7LMAAMXQCgpRs1kq/$(KGrHqRHJ!4FBQ!sVjWMBRs1kp8-Lg~~60_1.JPG?set_id=8800005007" }

        before do
          stub_request(:get, image_url).
            to_return(body: File.new(dumb_path), status: 200)


          allow(Storage).to receive(:extract_basename).and_return("1.jpg")
        end

        it "works" do
          post = LocalPost.create!
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

        end

        it "removes old picture" do
          post = LocalPost.create!
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
        stub_request(:any, image_url).to_return(body: File.new(dumb_path), status: 200)
      end

      it "works" do
        post = RemotePost.create!

        stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/1.jpg")
        stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg")
        stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg")

        expect(post.cover_image.present?).to eq false

        post.cover_image.download(image_url)

        post.reload

        expect(post[:cover_image]).to eq '1.jpg'
        expect(post.cover_image.present?).to eq true
        expect(post.cover_image.local_path.exist?).to eq false

        expect(post.cover_image.url).to eq "//#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/original/1.jpg"
      end
    end
  end

  describe "#remove" do
    context "remote upload" do
      let(:post) { RemotePost.create!(cover_image: '1.jpg') }

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

    context "local upload" do
      let(:post) { LocalPost.create!(cover_image: '1.jpg') }

      before do
        path = post.cover_image.local_path
        FileUtils.mkdir_p File.dirname(path)
        FileUtils.cp(fixture_upload('dumb.jpg'), path)
      end

      it "can be removed" do
        expect(post.cover_image.present?).to eq true

        post.cover_image.remove

        expect(post.cover_image.present?).to eq false
      end
    end
  end

  describe "#url" do
    let(:filename) { '1.jpg' }

    context "without upload" do
      it "returns nil" do
        post = LocalPost.create!

        expect(post.cover_image.url).to eq "/default/one_more_local_storage/original.png"
        expect(post.cover_image.url(:big)).to eq "/default/one_more_local_storage/big.png"
        expect(post.cover_image.url(:thumb)).to eq "/default/one_more_local_storage/thumb.png"
      end
    end

    context "not existing version" do
      it "throws exception" do
        post = LocalPost.create!(cover_image: filename)

        expect {
          post.cover_image.url(:somewhat)
        }.to raise_error(Storage::VersionNotExists)
      end
    end

    context "local upload" do
      it "works" do
        post = LocalPost.create!(cover_image: filename)

        allow(post.cover_image.versions[:original]).to receive(:local_copy_exists?).and_return(true)
        expect(post.cover_image.url).to eq "/uploads/post/#{post.id}/original/#{filename}"
      end
    end

    context "remote upload" do
      it "works" do
        post = RemotePost.create!(cover_image: filename)
        expect(post.cover_image.url).to eq "//#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/original/#{filename}"
        expect(post.cover_image.url(:big)).to eq "//#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/big/#{filename}"
      end
    end
  end

  describe "#as_json" do
    let(:filename) { '1.jpg' }

    context "file present" do
      it "works" do
        post = LocalPost.create!(cover_image: filename)

        urls = {
          original: "//#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/1/original/1.jpg",
          thumb: "//#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/1/thumb/1.jpg",
          big: "//#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/1/big/1.jpg"
        }

        expect(post.cover_image.as_json).to eq urls
      end
    end

    context "file absent" do
      it "works" do
        post = LocalPost.create!

        expect(post.cover_image.as_json).to eq nil
      end
    end
  end

  describe "#reprocess" do
    let(:image_url) { "http://putin.vor/1.jpg" }

    context "with remote storage" do
      before do
        stub_request(:any, image_url).to_return(body: File.new(dumb_path), status: 200)
      end

      it "works" do
        post = LocalPost.create!(cover_image: '1.jpg')

        expect(post.cover_image.present?).to eq true

        get_original = stub_request(:get, "http://#{Storage.bucket_name}.s3.amazonaws.com/uploads/post/#{post.id}/original/1.jpg").to_return(body: File.new(dumb_path), status: 200)

        # to replace
        stub_request(:head, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg")
        stub_request(:head, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/1.jpg")
        stub_request(:head, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg")
        stub_request(:delete, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg")
        stub_request(:delete, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/1.jpg")
        stub_request(:delete, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg")

        put_thumb = stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/thumb/1.jpg")
        put_original = stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/original/1.jpg")
        put_big = stub_request(:put, "https://#{Storage.bucket_name}.s3-eu-west-1.amazonaws.com/uploads/post/#{post.id}/big/1.jpg")

        post.cover_image.reprocess

        expect(get_original).to have_been_made.times(1)

        expect(put_original).to have_been_made.times(1)
        expect(put_thumb).to have_been_made.times(1)
        expect(put_big).to have_been_made.times(1)
      end
    end
  end

  describe "#versions" do
    it "are present" do
      post = LocalPost.create!(cover_image: '1.jpg')
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
