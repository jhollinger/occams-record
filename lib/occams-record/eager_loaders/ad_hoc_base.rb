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

      #
      # Initialize a new add hoc association.
      #
      # @param name [Symbol] name of attribute to load records into
      # @param mapping [Hash] a Hash with the key being the parent id and the value being fkey in the child
      # @param sql [String] the SQL to query the associated records. Include a bind params called '%{ids}' for the foreign/parent ids.
      # @param binds [Hash] any additional binds for your query.
      # @param model [ActiveRecord::Base] optional - ActiveRecord model that represents what you're loading. required when using Sqlite.
      # @param use [Array<Module>] optional - Ruby modules to include in the result objects (single or array)
      # @yield eager load associations nested under this one
      #
      def initialize(name, mapping, sql, binds: {}, model: nil, use: nil, &builder)
        @name, @mapping = name.to_s, mapping
        @sql, @binds, @use, @model = sql, binds, use, model
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
        fkey_binds = calc_fkey_binds rows
        assoc = if fkey_binds.any?(&:any?)
                  binds = @binds.merge(fkey_binds)
                  RawQuery.new(@sql, binds, use: @use, eager_loaders: @eager_loaders, query_logger: query_logger).run
                else
                  []
                end
        merge! assoc, rows
      end

      private

      #
      # Returns bind values from the parent rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      #
      def calc_fkey_binds(rows)
        @mapping.keys.reduce({}) { |a, fkey|
          a[fkey.to_s.pluralize.to_sym] = rows.reduce(Set.new) { |aa, row|
            begin
              val = row.send fkey
              aa << val if val
            rescue NoMethodError => e
              raise MissingColumnError.new(row, e.name)
            end
            aa
          }.to_a
          a
        }
      end

      def merge!(assoc_rows, rows)
        raise 'Not Implemented'
      end
    end
  end
end
