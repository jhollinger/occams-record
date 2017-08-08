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

    #
    # Initialize a new converter for a specific result set.
    #
    # @param column_names [Array<String>] the column names (same order as values)
    # @param column_types [Array] ActiveRecord column types (same order as values)
    #
    def initialize(names, types)
      @column_names = names
      @column_types = types
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
        col_val = if val.is_a? String
                    case column_types[i]
                    when :string then val
                    when :integer then val.to_i
                    # TODO
                    else val
                    end
                  else # Handle nil. Also, some types are converted for us esp. in Rails 5.
                    val
                  end
        a[col_name] = col_val
        a
      }
    end
  end
end
