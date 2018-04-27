module OccamsRecord
  module EagerLoaders
    #
    # Base class for eagoer loading an association. IMPORTANT eager loaders MUST remain stateless after initialization!
    #
    class Base
      # @return [String] association name
      attr_reader :name

      #
      # @param ref [ActiveRecord::Association] the ActiveRecord association
      # @param scope [Proc] a scope to apply to the query (optional). It will be passed an
      # ActiveRecord::Relation on which you may call all the normal query hethods (select, where, etc) as well as any scopes you've defined on the model.
      # @param use [Array(Module)] optional Module to include in the result class (single or array)
      # @param as [Symbol] Load the association usign a different attribute name
      # @yield perform eager loading on *this* association (optional)
      #
      def initialize(ref, scope = nil, use: nil, as: nil, &eval_block)
        @ref, @scope, @use, @as, @eval_block = ref, scope, use, as, eval_block
        @model = ref.klass
        @name = (as || ref.name).to_s
      end

      #
      # Run the query and merge the results into the given rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @param query_logger [Array<String>]
      #
      def run(rows, query_logger: nil)
        query(rows) { |*args|
          scope = args[0]
          assoc_rows = Query.new(scope, use: @use, query_logger: query_logger, &@eval_block).run
          merge! assoc_rows, rows, *args[1..-1]
        }
      end

      private

      #
      # Yield one or more ActiveRecord::Relation objects to a given block.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      #
      def query(rows)
        raise 'Not Implemented'
      end

      #
      # Merges the associated rows into the parent rows.
      #
      # @param assoc_rows [Array<OccamsRecord::Results::Row>]
      # @param rows [Array<OccamsRecord::Results::Row>]
      #
      def merge!(assoc_rows, rows)
        raise 'Not Implemented'
      end

      #
      # Returns the base scope for the relation, including any scope defined on the association itself,
      # and any optional scope passed into the eager loader.
      #
      # @return [ActiveRecord::Relation]
      #
      def base_scope
        q = @ref.klass.all
        q = q.instance_exec(&@ref.scope) if @ref.scope
        q = @scope.(q) if @scope
        q
      end
    end
  end
end
