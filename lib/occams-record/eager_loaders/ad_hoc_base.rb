module OccamsRecord
  module EagerLoaders
    #
    # Base class for eager loading ad hoc associations.
    #
    class AdHocBase
      # @return [String] association name
      attr_reader :name

      #
      # Initialize a new add hoc association.
      #
      # @param name [Symbol] name of attribute to load records into
      # @param mapping [Hash] a one element Hash with the key being the local/child id and the value being the foreign/parent id
      # @param sql [String] the SQL to query the associated records. Include a bind params called '%{ids}' for the foreign/parent ids.
      # @param binds [Hash] any additional binds for your query.
      # @param use [Array<Module>] optional - Ruby modules to include in the result objects (single or array)
      # @param model [ActiveRecord::Base] optional - ActiveRecord model that represents what you're loading. required when using Sqlite.
      #
      def initialize(name, mapping, sql, binds = {}, use: nil, model: nil)
        @name = name.to_s
        @sql, @binds, @use, @model = sql, binds, use, model
        raise ArgumentError, "Add-hoc eager loading mapping must contain exactly one key-value pair" unless mapping.size == 1
        @local_key = mapping.keys.first
        @foreign_key = mapping.fetch(@local_key)
      end

      #
      # Run the query and merge the results into the given rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @param query_logger [Array<String>]
      #
      def run(rows, query_logger: nil)
        calc_ids(rows) { |ids|
          binds = @binds.merge({:ids => ids})
          assoc_rows = RawQuery.new(@sql, binds, use: @use, query_logger: query_logger).model(@model).run
          merge! assoc_rows, rows
        }
      end

      private

      #
      # Yield ids from the parent association to a block.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @yield
      #
      def calc_ids(rows)
        ids = rows.map { |r| r.send @foreign_key }.compact.uniq
        yield ids
      end

      def merge!(assoc_rows, rows)
        raise 'Not Implemented'
      end
    end
  end
end
