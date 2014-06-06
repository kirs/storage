# Storage

[![Build Status](https://travis-ci.org/kirs/storage.svg?branch=master)](https://travis-ci.org/kirs/storage)
[![Code Climate](https://codeclimate.com/github/kirs/storage.png)](https://codeclimate.com/github/kirs/storage)

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'storage'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install storage

You can configure `Storage` in initializer:

```ruby
# config/initializers/storage.rb
Storage.setup do |config|
  secrets = Rails.application.secrets[:s3]
  if secrets.nil?
    raise ArgumentError.new("secrets.yml doesn't have credentials for S3")
  end

  # only if you use Amazon S3
  config.s3_credentials = {
    access_key_id: secrets['access_key'],
    secret_access_key: secrets['secret_key'],
    region: secrets['region']
  }

  # only if you use Amazon S3
  config.bucket_name = 'my-app-bucket'
end
```

## Usage

Firstly, you need to declare `Storage` model:

```ruby
# app/storages/cover_photo_storage.rb
class CoverPhotoStorage < Storage::Model
  version :original
  version :thumb, resize: "200x200"
  version :big, resize: "300x300"

  # leave this if you want to use S3 as a storage
  def remote_storage_enabled?
    true
  end
end
```

And then mount CoverPhotoStorage into your model:

```ruby
# app/models/post.rb
class Post < ActiveRecord::Base
  def cover_photo
    @cover_photo ||= CoverPhotoStorage.new(self, :cover_photo)
  end
end
```

* Don't forget to add `cover_photo` column into your schema *

Now you can use Storage API:

```ruby
post = Post.create!
post.cover_photo.download("http://example.com/photo.jpg")
post.cover_photo.present?
=> true
post.cover_photo.url
=> 'https://yourbucker.s3-eu-west-1.amazonaws.com/uploads/post/1/original/photo.jpg'
post.cover_photo.url(:big)
=> 'https://yourbucker.s3-eu-west-1.amazonaws.com/uploads/post/1/big/photo.jpg'
post.cover_photo.remove
=> true
post.cover_photo.present?
=> false

post.cover_photo.store(File.open('/var/www/somefile.jpg'))
post.cover_photo.present?
=> true
post.cover_photo.local_path
=> /path/to/rails/public/uploads/post/1/big/photo.jpg
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/storage/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
