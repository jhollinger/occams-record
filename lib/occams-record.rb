require 'active_record'
require 'occams-record/version'
require 'occams-record/merge'
require 'occams-record/measureable'
require 'occams-record/eager_loaders/eager_loaders'
require 'occams-record/type_caster'
require 'occams-record/results/results'
require 'occams-record/results/row'
require 'occams-record/pluck'
require 'occams-record/cursor'
require 'occams-record/errors'

require 'occams-record/batches/offset_limit/scoped'
require 'occams-record/batches/offset_limit/raw_query'
require 'occams-record/batches/cursor_helpers'

require 'occams-record/binds_converter'
require 'occams-record/binds_converter/abstract'
require 'occams-record/binds_converter/named'
require 'occams-record/binds_converter/positional'

require 'occams-record/query'
require 'occams-record/raw_query'

module OccamsRecord
  autoload :Ugly, 'occams-record/ugly'
end
