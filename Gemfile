source 'https://rubygems.org'

gemspec

gem 'rake'

gem 'activerecord', {
  '4.2' => '~> 4.2.9',
  '5.0' => '~> 5.0.5',
  '5.1' => '~> 5.1.3',
  '5.2' => '~> 5.2.0',
  '6.0' => '~> 6.0.0',
  '6.1' => '~> 6.1.3.2',
}[ENV['AR']]

group :development do
  gem 'memory_profiler'
end

group :test do
  gem 'minitest'
  gem 'database_cleaner'
end

group :development, :test do
  gem 'otr-activerecord', '~> 1.4'
  gem 'sqlite3', {
    '4.2' => '~> 1.3.6',
    '5.0' => '~> 1.3.6',
    '5.1' => '~> 1.3.6',
    '5.2' => '~> 1.3.6',
  }[ENV['AR']] || '~> 1.4.1'
  gem 'pg', '~> 1.0'
end
