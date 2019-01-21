require 'active_record'
require 'occams-record/version'
require 'occams-record/merge'
require 'occams-record/eager_loaders'
require 'occams-record/results/results'
require 'occams-record/results/row'
require 'occams-record/query'
require 'occams-record/raw_query'
require 'occams-record/errors'

module OccamsRecord
  autoload :Ugly, 'occams-record/ugly'
end
