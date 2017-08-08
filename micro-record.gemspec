require_relative 'lib/micro-record/version'

Gem::Specification.new do |s|
  s.name = 'micro-record'
  s.version = MicroRecord::VERSION
  s.licenses = []
  s.summary = 'Low-memory ActiveRecord-based query library'
  s.description = 'A library for querying very large sets of ActiveRecord records as read-only, minimal Hashes'
  s.date = '2017-08-07'
  s.authors = ['Jordan Hollinger']
  s.email = 'jordan.hollinger@gmail.com'
  s.homepage = 'https://github.com/jhollinger/micro-record'
  s.require_paths = ['lib']
  s.files = [Dir.glob('lib/**/*'), 'README.md'].flatten
  s.required_ruby_version = '>= 2.1.0'
  s.add_runtime_dependency 'activerecord', ['>= 4.2', '< 5.1']
end
