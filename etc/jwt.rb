# frozen_string_literal: true

require "bundler/inline"

gemfile(true, quiet: true) do
  source 'https://rubygems.org'

  gem "jwt"
end

id = rand(100)

require "jwt"
require "json"

SECRET = ENV["ANYCABLE_JWT_SECRET"] || "secret"

exp = Time.now.to_i + 360
payload = {ext: {id: id}.to_json, exp: exp}

puts JWT.encode payload, SECRET, "HS256"
