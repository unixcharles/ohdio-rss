source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "solid_queue"
gem "bootsnap", require: false
gem "thruster", require: false

gem "ohdio", path: "vendor/ohdio"
gem "down"
gem "pagy"
gem "ostruct"

group :development, :test do
  gem "sqlite3", ">= 2.1"
  gem "rspec-rails"
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end
