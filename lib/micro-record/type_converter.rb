module MicroRecord
  #
  # Contains type converts (raw db results -> native Ruby types) for various database adapters.
  #
  module TypeConverter
    autoload :Base, 'micro-record/type_converters/base'
    autoload :PostgreSQL, 'micro-record/type_converters/postgresql'
    autoload :SQLite, 'micro-record/type_converters/sqlite'

    #
    # Return the converter class for the given adapter. Raises an exception if it isn't supported.
    #
    # @param adapter_name [String] name of database adapter, e.g. 'PostgreSQL'
    # @return [MicroRecord::TypeConverter::Base]
    #
    def self.fetch!(adapter_name)
       case adapter_name
       when 'PostgreSQL'.freeze then PostgreSQL
       when 'SQLite'.freeze then SQLite
       else raise "MicroRecord::TypeConverter: unsupported adapter `#{adapter_name}`"
       end
    end
  end
end
