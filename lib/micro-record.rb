begin
  require 'multi_json'
rescue LoadError
  require 'json'
end

require 'micro-record/version'
require 'micro-record/eager_loaders'
require 'micro-record/type_converter'
require 'micro-record/query'
