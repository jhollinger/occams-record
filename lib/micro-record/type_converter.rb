module MicroRecord
  #
  # A class for converting string results to Ruby types. Since ActiveRecord::Result returns many
  # values as Strings, we need to convert them manually.
  #
  class TypeConverter
    # @return [Array<String>] the column names
    attr_reader :column_names
    # @return [Array<Symbol>] the column types
    attr_reader :column_types
    # @return [Symbol] name of db-specific converter method
    attr_reader :converter

    # Regex to parse PG's hstore format
    PG_HSTORE_REGEXP = /"([^"]+)"=>"([^"]+)"/

    #
    # Initialize a new converter for a specific result set.
    #
    # @param adapter_name [String] name of database adapter, e.g. 'PostgreSQL'
    # @param column_names [Array<String>] the column names (same order as values)
    # @param column_types [Array] ActiveRecord column types (same order as values)
    #
    def initialize(adapter_name, names, types)
      @column_names = names
      @column_types = types
      @converter = case adapter_name
                   when 'PostgreSQL'.freeze then :pg_convert
                   else raise "MicroRecord::TypeConverter: unsupported adapter `#{adapter_name}`"
                   end
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

    private

    #
    # Converter for PG data types.
    #
    # @param val [String] unconverted value
    # @param type [Symbol] type identifier
    # @return [Object] value as a native type
    #
    def pg_convert(val, type)
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
      when :json
        MultiJson.load val
      when :hstore
        Hash[ val.scan PG_HSTORE_REGEXP ]
      when :array
        # TODO handle quoted in values, i.e. values that contain comas or quotes
        val[1..-2].split ','.freeze
      else
        $stderr.puts "WARNING: MicroRecord::TypeConverter: unsupported column type `#{type}`"
        val
      end
    end
  end
end
