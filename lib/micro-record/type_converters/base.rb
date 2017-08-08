module MicroRecord
  module TypeConverter
    #
    # Base class for converting string results to Ruby types. Since ActiveRecord::Result returns many
    # values as Strings, we need to convert them manually. There is a subclass for each supported
    # database adapter.
    #
    class Base
      # @return [Array<Symbol>] the column types
      attr_reader :column_types
      # @return [Array<String>] the column names
      attr_reader :column_names

      #
      # Initialize a new converter for a specific result set.
      #
      # @param column_types [Array] ActiveRecord column types (same order as values)
      # @param column_names [Array<String>] the column names (same order as values). You only need to include these
      # if you plan to use MicroRecord::TypeConverter#to_hash.
      #
      def initialize(types, names = [])
        @column_types = types
        @column_names = names
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
          a[col_name] = convert_val val, column_types[i]
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
          a << convert_val(val, column_types[i])
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
        convert_val val, column_types[i]
      end

      private

      #
      # Adapter-specific implementation.
      #
      # @param val raw value from adapter
      # @param type [Symbol] name of Ruby type
      # @return [Object] val as native type
      #
      def convert_val(val, type)
        raise 'Not Implemented'
      end
    end
  end
end
