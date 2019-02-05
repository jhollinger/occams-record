source 'https://rubygems.org'

gemspec

gem 'rake'

gem 'activerecord', {
  '4.2' => '~> 4.2.9',
  '5.0' => '~> 5.0.5',
  '5.1' => '~> 5.1.3',
  '5.2' => '~> 5.2.0',
}[ENV['AR']]

group :development do
  gem 'memory_profiler'
end

group :test do
  gem 'minitest'
  gem 'database_cleaner'
end

group :development, :test do
  gem 'otr-activerecord', '~> 1.2.5'
  gem 'sqlite3', '~> 1.3.6'
end
