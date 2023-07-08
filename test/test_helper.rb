require 'json'
require 'occams-record'
require 'active_record'
require 'minitest/autorun'
Dir.glob('./test/support/*.rb').each { |file| require file }
TestHelpers.load_fixtures!
