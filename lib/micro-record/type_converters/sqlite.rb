module MicroRecord
  module TypeConverter
    # Type converter for sqlite connections.
    class SQLite < Base
      private

      #
      # Converter for SQLite data types.
      #
      # @param val [String] unconverted value
      # @param type [Symbol] type identifier
      # @return [Object] value as a native type
      #
      def convert_val(val, type)
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
    end
  end
end
