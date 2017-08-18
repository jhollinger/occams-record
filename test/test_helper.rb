require 'json'
require 'occams-record'
require 'active_record'
require 'minitest/autorun'
Dir.glob('./test/support/*.rb').each { |file| require file }
puts "Testing against ActiveRecord version #{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
TestHelpers.load_fixtures!
