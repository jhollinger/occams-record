require 'set'

module OccamsRecord
  module EagerLoaders
    #
    # Base class for eager loading ad hoc associations.
    #
    class AdHocBase
      include EagerLoaders::Builder

      # @return [String] association name
      attr_reader :name

      # @return [OccamsRecord::EagerLoaders::Tracer | nil] a reference to this eager loader and its parent (if any)
      attr_reader :tracer

      # @return [OccamsRecord::EagerLoaders::Context]
      attr_reader :eager_loaders

      #
      # Initialize a new add hoc association.
      #
      # @param name [Symbol] name of attribute to load records into
      # @param mapping [Hash] a Hash with the key being the parent id and the value being fkey in the child
      # @param sql [String] the SQL to query the associated records. Include a bind params called '%{ids}' for the foreign/parent ids.
      # @param binds [Hash] any additional binds for your query.
      # @param model [ActiveRecord::Base] optional - ActiveRecord model that represents what you're loading. required when using Sqlite.
      # @param use [Array<Module>] optional - Ruby modules to include in the result objects (single or array)
      # @param parent [OccamsRecord::EagerLoaders::Tracer] the eager loader this one is nested under (if any)
      # @yield eager load associations nested under this one
      #
      def initialize(name, mapping, sql, binds: {}, model: nil, use: nil, parent: nil, &builder)
        @name, @mapping = name.to_s, mapping
        @sql, @binds, @use, @model = sql, binds, use, model
        @tracer = Tracer.new(name, parent)
        @eager_loaders = EagerLoaders::Context.new(@model, tracer: @tracer)
        if builder
          if builder.arity > 0
            builder.call(self)
          else
            instance_exec(&builder)
          end
        end
      end

      #
      # Run the query and merge the results into the given rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @param query_logger [Array<String>]
      #
      def run(rows, use_cursor: false, query_logger: nil, measurements: nil)
        fkey_binds = calc_fkey_binds rows
        assoc =
          if fkey_binds.all? { |_, vals| vals.any? }
            binds = @binds.merge(fkey_binds)
            q = RawQuery.new(@sql, binds, use: @use, eager_loaders: @eager_loaders, query_logger: query_logger, measurements: measurements)
            use_cursor ? q.find_each_with_cursor.to_a : q.to_a
          else
            []
          end
        merge! assoc, rows
        nil
      end

      private

      #
      # Returns bind values from the parent rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      #
      def calc_fkey_binds(rows)
        @mapping.keys.each_with_object({}) { |fkey, acc|
          acc[fkey.to_s.pluralize.to_sym] = rows.each_with_object(Set.new) { |row, acc2|
            begin
              val = row.send fkey
              acc2 << val if val
            rescue NoMethodError => e
              raise MissingColumnError.new(row, e.name)
            end
          }.to_a
        }
      end

      def merge!(assoc_rows, rows)
        raise 'Not Implemented'
      end
    end
  end
end
