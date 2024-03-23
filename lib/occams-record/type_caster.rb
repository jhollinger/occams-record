module OccamsRecord
  module TypeCaster
    # @private
    CASTER =
      case ActiveRecord::VERSION::MAJOR
      when 6, 7 then :deserialize
      else raise "OccamsRecord::TypeCaster::CASTER does yet support this version of ActiveRecord"
      end

    #
    # Returns a Hash containing type converters (a Proc) for each column. The Proc's accept a value and return a converted value, mapping enum values from the model if necessary.
    #
    # NOTE Some columns may have no Proc (particularly if you're using SQLite and running a raw SQL query).
    #
    # @param column_names [Array<String>] the column names in the result set (ActiveRecord::Result#columns). The order MUST match the order returned by the query.
    # @param column_types [Hash] Column name => type (ActiveRecord::Result#column_types)
    # @param model [ActiveRecord::Base] the AR model representing the table (it holds column & type info as well as enums).
    # @return [Hash<Proc>] a Hash of casting Proc's keyed by column
    #
    def self.generate(column_names, column_types, model: nil)
      column_names.each_with_object({}) { |col, memo|
        #
        # NOTE there's lots of variation between DB adapters and AR versions here. Some notes:
        # * Postgres AR < 6.1 `column_types` will contain entries for every column.
        # * Postgres AR >= 6.1 `column_types` only contains entries for "exotic" types. Columns with "common" types have already been converted by the PG adapter.
        # * SQLite `column_types` will always be empty. Some types will have already been convered by the SQLite adapter, but others will depend on
        #   `model_column_types` for converstion. See test/raw_query_test.rb#test_common_types for examples.
        # * MySQL ?
        #
        type = column_types[col] || model&.attributes_builder&.types&.[](col)

        #
        # NOTE is also some variation in when enum values are mapped in different AR versions.
        # In >=5.0, <=7.0, ActiveRecord::Result objects *usually* contain the human-readable values. In 4.2 and
        # pre-release versions of 7.1, they instead have the RAW values (e.g. integers) which we must map ourselves.
        #
        enum = model&.defined_enums&.[](col)
        inv_enum = enum&.invert

        memo[col] =
          case type&.type
          when nil
            if enum
              ->(val) { enum.has_key?(val) ? val : inv_enum[val] }
            end
          when :datetime
            ->(val) { type.send(CASTER, val)&.in_time_zone }
          else
            if enum
              ->(val) {
                val = type.send(CASTER, val)
                enum.has_key?(val) ? val : inv_enum[val]
              }
            else
              ->(val) { type.send(CASTER, val) }
            end
          end
      }
    end
  end
end
