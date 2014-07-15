# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "storage"
  spec.version       = "0.0.1"
  spec.authors       = ["Kir Shatrov"]
  spec.email         = ["shatrov@me.com"]
  spec.summary       = %q{Simple stupid remote file uploads for Rails 4.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0.0.beta2"
  spec.add_development_dependency "activerecord", "~> 4.1.0"

  spec.add_development_dependency 'database_cleaner', '>= 1.2.0'
  spec.add_development_dependency 'timecop'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'rack-test'

  spec.add_dependency "aws-sdk", "~> 1.0"
  spec.add_dependency "mini_magick"
  spec.add_dependency "curb"
end
