# Storage

[![Build Status](https://travis-ci.org/kirs/storage.svg?branch=master)](https://travis-ci.org/kirs/storage)
[![Code Climate](https://codeclimate.com/github/kirs/storage.png)](https://codeclimate.com/github/kirs/storage)

At [Evil Martians](http://evl.ms), we use Carrierwave to store billions of files in S3 cloud and we faced with such issues:

* with [carrierwave-backgrounder](https://github.com/lardawge/carrierwave_backgrounder), logic becomes too complex
* it creates [bunch](https://github.com/lardawge/carrierwave_backgrounder/blob/master/lib/backgrounder/orm/activemodel.rb) of [callbacks](https://github.com/lardawge/carrierwave_backgrounder/blob/master/lib/backgrounder/orm/base.rb) and magick attributes inside AR::Base model
* Rails 4 way prefers [using Service and Value objects](http://blog.codeclimate.com/blog/2012/10/17/7-ways-to-decompose-fat-activerecord-models/) for complex logic inside the Model

So what we need, is the solution to:

* download remote image
* save it locally
* process it (including resize and watermarks)
* transfer it to S3 in background if we need to
* backup it
* reprocess photo if size was changed

## Installation

Add this line to your application's Gemfile:

    gem 'storage'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install storage

Then you can configure `Storage` in Rails initializer:

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
  config.bucket_name = "my-app_#{Rails.env}"
end
```

## Usage

Firstly, you need to declare `Storage` model (almost like `Uploader` you used in CarrierWave):

```ruby
# app/storages/cover_photo_storage.rb
class CoverPhotoStorage < Storage::Model
  version :original
  version :thumb, size: "200x200"
  version :big, size: "300x300"

  # leave this if you want to use S3 as a storage
  store_remotely

  # define how you would like to modify the image
  def process_image(version, image)
    # image is original, instance of MiniMagick::Image
    # you can transform existing image object or return the new one
    if version.options[:size].present?
      image.resize(version.options[:size])
    end
  end

  # optionally: redefine to use custom uploads path
  def model_uploads_path(version)
    File.join("uploads", @model.class.name.underscore, @model.id.to_s, version)
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

_Don't forget to add `cover_photo` column into your DB scheme_

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

# or store with custom name:
post.cover_photo.store(File.open('/var/www/somefile.jpg'), filename: 'photo.jpg')

post.cover_photo.present?
=> true
post.cover_photo.local_path
=> /path/to/rails/public/uploads/post/1/big/photo.jpg

# to reprocess all records
Post.find_each do |post|
  post.cover_photo.reprocess
end
```

## Alias AWS S3 URLs

You may want to proxy/alias S3 assets throught your servers to hide original URL or to reduce S3 trafic using caching.

It's easy to write your own `Remote` backend:

```ruby
class CustomRemote < Storage::Remote
  def url_for(filename, with_protocol: false)
    protocol_prefix = if with_protocol
      "http:"
    else
      ""
    end

    "#{protocol_prefix}//storage.yourcompany.com/#{filename}"
  end
end
```

```ruby
class PhotoStorage < Storage::Model
  version :original
  version :big

  def remote_klass
    CustomRemote
  end
end
```

```
post = Post.last
post.photo.url # returns your custom url instead of URL on amazonaws.com domain
=> //storage.yourcompany.com/uploads/post/1/big/1.jpg
```

## Optimizations with jpegoptim & optipng

Using [Piet](https://github.com/albertbellonch/piet), Storage can optimize your images with `jpegoptim` and `optipng`:

```ruby
class PhotoStorage < Storage::Model
  include Storage::Helpers::OptimizeHelper

  # declare versions...

  def process_image(version, image)
    optimize_with_piet(image)
  end
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/storage/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
