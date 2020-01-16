
# rubocop:disable all

source "https://rubygems.org"

gem "rails", "~> 6.0"
gem "puma"
gem "redis"

# Install from source for Ruby 2.7 (no precompiled binaries available yet)
gem "google-protobuf", git: "https://github.com/google/protobuf"

if File.directory?("../anycable")
  gem "anycable", path: "../anycable"
else
  gem "anycable"
end

if File.directory?("../anycable-rails")
  gem "anycable-rails", path: "../anycable-rails"
else
  gem "anycable-rails"
end

gem "pry-byebug"
