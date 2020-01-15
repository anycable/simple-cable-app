
# rubocop:disable all

source "https://rubygems.org"

gem "rails", "~> 6.0"
gem "puma"
gem "redis"

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
