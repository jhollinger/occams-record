source 'https://rubygems.org'

gemspec

gem 'rake'

gem 'activerecord', {
  '4.2' => '~> 4.2.9',
  '5.0' => '~> 5.0.5',
}[ENV['AR']]

group :test do
  gem 'minitest'
  gem 'otr-activerecord', '~> 1.2.0'
  gem 'sqlite3'
  gem 'database_cleaner'
end
