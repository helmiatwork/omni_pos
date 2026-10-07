source "https://rubygems.org"

gem "rails", "~> 8.0"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "inertia_rails"
gem "vite_rails"
gem "bcrypt", "~> 3.1.7"
gem "money"
gem "json", "~> 3.0"

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :test do
  gem "database_cleaner-active_record"
  gem "simplecov", require: false
end
