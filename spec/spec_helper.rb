# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
# require File.expand_path("../../config/environment", __FILE__)
# require 'rspec/rails'
require 'database_cleaner'
require 'webmock/rspec'
require 'active_record'
require 'storage'
require 'timecop'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

DatabaseCleaner.strategy = :transaction

I18n.enforce_available_locales

def public_path( *paths )
  File.expand_path(File.join(File.dirname(__FILE__), 'public', *paths))
end

Storage.setup do |config|
  config.s3_credentials = {
    access_key_id: 'foo',
    secret_access_key: 'bar',
    region: 'eu-west-1'
  }
  config.storage_path = Pathname.new(public_path)
end


RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.order = "random"

  config.before(:suite) do
    # Sidekiq::Testing.fake!

    begin
      DatabaseCleaner.start
    ensure
      DatabaseCleaner.clean
    end
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.after :each do
    Timecop.return
  end
end
