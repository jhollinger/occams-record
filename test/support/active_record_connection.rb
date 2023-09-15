require 'otr-activerecord'

if ENV["TEST_DATABASE_URL"].to_s != ""
  OTR::ActiveRecord.configure_from_url!(ENV["TEST_DATABASE_URL"])
else
  OTR::ActiveRecord.configure_from_hash!(adapter: 'sqlite3', database: ':memory:', encoding: 'utf8', pool: 5, timeout: 5000)
end
