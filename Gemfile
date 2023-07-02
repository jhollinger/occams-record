source 'https://rubygems.org'

gemspec

gem 'rake'
gem 'memory_profiler'
# NOTE we're pulling from Github b/c ruby 3.2 doesn't (yet) work with any released version. Hopefully in >2.4.1.
# See https://github.com/thoughtbot/appraisal/issues/199
gem 'appraisal', git: 'https://github.com/thoughtbot/appraisal.git', ref: 'b200e636903700098bef25f4f51dbc4c46e4c04c'

group :test do
  gem 'minitest'
  gem 'database_cleaner'
end
