source 'https://rubygems.org'

gemspec

gem 'rake'

gem 'activerecord', {
  '4.2' => '~> 4.2.9',
  '5.0' => '~> 5.0.5',
  '5.1' => '~> 5.1.3',
}[ENV['AR']]

group :test do
  gem 'minitest'
  gem 'otr-activerecord', '~> 1.2.3'
  gem 'sqlite3'
  gem 'database_cleaner'
end
