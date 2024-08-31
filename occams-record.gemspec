require_relative 'lib/occams-record/version'

Gem::Specification.new do |s|
  s.name = 'occams-record'
  s.version = OccamsRecord::VERSION
  s.licenses = ['MIT']
  s.summary = 'The missing high-efficiency query API for ActiveRecord'
  s.description = 'A faster, lower-memory, fuller-featured querying API for ActiveRecord that returns results as unadorned, read-only objects.'
  s.authors = ['Jordan Hollinger']
  s.email = 'jordan.hollinger@gmail.com'
  s.homepage = 'https://jhollinger.github.io/occams-record/'
  s.require_paths = ['lib']
  s.files = [Dir.glob('lib/**/*'), 'README.md'].flatten
  s.required_ruby_version = '>= 3.0.0'
  s.add_runtime_dependency 'activerecord', ['>= 6.0', '< 7.3']
end
