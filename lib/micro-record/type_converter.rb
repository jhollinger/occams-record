module MicroRecord
  #
  # A class for converting string results to Ruby types. Since ActiveRecord::Result returns many
  # values as Strings, we need to convert them manually.
  #
  class TypeConverter
    # @return [Array<Symbol>] the column types
    attr_reader :column_types
    # @return [Array<String>] the column names
    attr_reader :column_names
    # @return [Symbol] name of db-specific converter method
    attr_reader :converter
    # @return [Symbol] name of json loader
    attr_reader :json_loader

    # Regex to parse PG's hstore format. NOTE does not correctly handle double quotes in keys and values.
    PG_HSTORE_REGEXP = /"([^"]+)"=>"([^"]+)"/

    #
    # Initialize a new converter for a specific result set.
    #
    # @param adapter_name [String] name of database adapter, e.g. 'PostgreSQL'
    # @param column_types [Array] ActiveRecord column types (same order as values)
    # @param column_names [Array<String>] the column names (same order as values). You only need to include these
    # if you plan to use MicroRecord::TypeConverter#to_hash.
    #
    def initialize(adapter_name, types, names = [])
      @column_types = types
      @column_names = names
      @converter = case adapter_name
                   when 'PostgreSQL'.freeze then :convert_pg
                   when 'SQLite'.freeze then :convert_sqlite
                   else raise "MicroRecord::TypeConverter: unsupported adapter `#{adapter_name}`"
                   end
      @json_loader = defined?(MultiJson) ? :multi_json : :stdlib_json
    end

    #
    # Convert an array of column values to a Hash with string keys and native values.
    #
    # @param row [Array]
    # @return [Hash]
    #
    def to_hash(row)
      row.each_with_index.reduce({}) { |a, (val,i)|
        col_name = column_names[i]
        a[col_name] = send converter, val, column_types[i]
        a
      }
    end

    #
    # Convert an array of column string values to an array of native types.
    #
    # @param row [Array]
    # @return [Array]
    #
    def to_array(row)
      row.each_with_index.reduce([]) { |a, (val,i)|
        a << send(converter, val, column_types[i])
      }
    end

    #
    # Convert a single value by column index.
    #
    # @param val [String] string value
    # @param i [Integer] index of column
    # @return [Object] native type
    #
    def convert(val, i)
      send converter, val, column_types[i]
    end

    private

    #
    # Converter for PG data types.
    #
    # @param val [String] unconverted value
    # @param type [Symbol] type identifier
    # @return [Object] value as a native type
    #
    def convert_pg(val, type)
      return val unless val.is_a? String # handle values that were already converted. also nil.
      return nil if val == 'NULL'.freeze

      case type
      when :string, :text, :uuid then val
      when :integer then val.to_i
      when :float then val.to_f
      when :decimal
        BigDecimal.new(val)
      when :boolean
        case val
        when 't'.freeze then true
        when 'f'.freeze then false
        end
      when :date
        Date.iso8601(val)
      when :datetime
        Time.strptime(val, '%Y-%m-%d %H:%M:%S.%L')
      when :time
        Time.strptime(val, '%H:%M:%S')
      when :json
        send json_loader, val
      when :hstore
        # TODO handle double quotes in keys and values
        Hash[ val.scan PG_HSTORE_REGEXP ]
      when :array
        # TODO handle quoted in values, i.e. values that contain comas or quotes
        val[1..-2].split ','.freeze
      else
        $stderr.puts "WARNING: MicroRecord::TypeConverter: unsupported column type `#{type}` for PostgreSQL"
        val
      end
    end

    #
    # Converter for SQLite data types.
    #
    # @param val [String] unconverted value
    # @param type [Symbol] type identifier
    # @return [Object] value as a native type
    #
    def convert_sqlite(val, type)
      return val unless val.is_a? String # handle values that were already converted. also nil.
      return nil if val == 'NULL'.freeze

      case type
      when :string, :text, :uuid then val
      when :integer then val.to_i
      when :float then val.to_f
      when :decimal
        BigDecimal.new(val)
      when :boolean
        case val
        when 't'.freeze then true
        when 'f'.freeze then false
        end
      when :date
        Date.iso8601(val)
      when :datetime, :time
        Time.iso8601(val)
      else
        $stderr.puts "WARNING: MicroRecord::TypeConverter: unsupported column type `#{type}` for SQLite"
        val
      end
    end

    # Uses the built-in JSON library to parse the expression.
    def stdlib_json(exp)
      JSON.parse exp
    end

    # Uses the MultiJson library to parse the expression.
    def multi_json(exp)
      MultiJson.load exp
    end
  end
end
