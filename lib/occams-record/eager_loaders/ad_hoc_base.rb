module OccamsRecord
  module EagerLoaders
    #
    # Base class for eager loading ad hoc associations.
    #
    class AdHocBase
      include EagerLoaders::Builder

      # @return [String] association name
      attr_reader :name

      #
      # Initialize a new add hoc association.
      #
      # @param name [Symbol] name of attribute to load records into
      # @param mapping [Hash] a one element Hash with the key being the local/child id and the value being the foreign/parent id
      # @param sql [String] the SQL to query the associated records. Include a bind params called '%{ids}' for the foreign/parent ids.
      # @param binds [Hash] any additional binds for your query.
      # @param model [ActiveRecord::Base] optional - ActiveRecord model that represents what you're loading. required when using Sqlite.
      # @param use [Array<Module>] optional - Ruby modules to include in the result objects (single or array)
      # @yield eager load associations nested under this one
      #
      def initialize(name, mapping, sql, binds: {}, model: nil, use: nil, &builder)
        @name = name.to_s
        @sql, @binds, @use, @model = sql, binds, use, model
        raise ArgumentError, "Add-hoc eager loading mapping must contain exactly one key-value pair" unless mapping.size == 1
        @local_key = mapping.keys.first
        @foreign_key = mapping.fetch(@local_key)
        @eager_loaders = EagerLoaders::Context.new(@model)
        instance_eval(&builder) if builder
      end

      #
      # Run the query and merge the results into the given rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @param query_logger [Array<String>]
      #
      def run(rows, query_logger: nil)
        calc_ids(rows) { |ids|
          assoc = if ids.any?
                    binds = @binds.merge({:ids => ids})
                    RawQuery.new(@sql, binds, use: @use, eager_loaders: @eager_loaders, query_logger: query_logger).run
                  else
                    []
                  end
          merge! assoc, rows
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
        ids = rows.map { |row|
          begin
            row.send @foreign_key
          rescue NoMethodError => e
            raise MissingColumnError.new(row, e.name)
          end
        }.compact.uniq
        yield ids
      end

      def merge!(assoc_rows, rows)
        raise 'Not Implemented'
      end
    end
  end
end
