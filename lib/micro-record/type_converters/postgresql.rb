module MicroRecord
  module TypeConverter
    # Type converter for postgresql connections.
    class PostgreSQL < Base
      # Regex to parse PG's hstore format. NOTE does not correctly handle double quotes in keys and values.
      PG_HSTORE_REGEXP = /"([^"]+)"=>"([^"]+)"/

      private

      #
      # Converter for PG data types.
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
        when :datetime
          Time.strptime(val, '%Y-%m-%d %H:%M:%S.%L')
        when :time
          Time.strptime(val, '%H:%M:%S')
        when :json
          load_json val
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

      if defined? MultiJson
        def load_json(val)
          MultiJson.load val
        end
      else
        def load_json(val)
          JSON.parse val
        end
      end
    end
  end
end
