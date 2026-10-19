# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "bcrypt", "~> 3.1"
gem "pg", "~> 1.7"
gem "puma", "~> 8.0"
gem "rack", "~> 3.2"
gem "rake", "~> 13.4"
gem "sequel", "~> 5.109"
gem "sidekiq", "~> 8.1"

group :development, :test do
  gem "rack-test", "~> 2.2"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.92", require: false
  gem "rubocop-rspec", "~> 3.10", require: false
end
