module OccamsRecord
  module EagerLoaders
    # A low-memory way to trace the path of eager loads from any point back to the root query
    Tracer = Struct.new(:name, :parent)

    #
    # Base class for eagoer loading an association. IMPORTANT eager loaders MUST remain stateless after initialization!
    #
    class Base
      include EagerLoaders::Builder

      # @return [String] association name
      attr_reader :name

      # @return [OccamsRecord::EagerLoaders::Tracer | nil] a reference to this eager loader and its parent (if any)
      attr_reader :tracer

      #
      # @param ref [ActiveRecord::Association] the ActiveRecord association
      # @param scope [Proc] a scope to apply to the query (optional). It will be passed an
      # ActiveRecord::Relation on which you may call all the normal query hethods (select, where, etc) as well as any scopes you've defined on the model.
      # @param use [Array(Module)] optional Module to include in the result class (single or array)
      # @param as [Symbol] Load the association usign a different attribute name
      # @param optimizer [Symbol] Only used for `through` associations. Options are :none (load all intermediate records) | :select (load all intermediate records but only SELECT the necessary columns)
      # @param parent [OccamsRecord::EagerLoaders::Tracer] the eager loader this one is nested under (if any)
      # @yield perform eager loading on *this* association (optional)
      #
      def initialize(ref, scope = nil, use: nil, as: nil, optimizer: :select, parent: nil, &builder)
        @ref, @scopes, @use, @as = ref, Array(scope), use, as
        @model = ref.klass
        @name = (as || ref.name).to_s
        @eager_loaders = EagerLoaders::Context.new(@model, owner: self)
        @optimizer = optimizer
        @tracer = Tracer.new(name, parent)
        if builder
          if builder.arity > 0
            builder.call(self)
          else
            instance_exec(&builder)
          end
        end
      end

      #
      # An alternative to passing a "scope" lambda to the constructor. Your block is passed the query
      # so you can call select, where, order, etc on it.
      #
      # If you call scope multiple times, the results will be additive.
      #
      # @yield [ActiveRecord::Relation] a relation to modify with select, where, order, etc
      # @return self
      #
      def scope(&scope)
        @scopes << scope if scope
        self
      end

      #
      # Run the query and merge the results into the given rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @param query_logger [Array<String>]
      #
      def run(rows, query_logger: nil, measurements: nil)
        query(rows) { |*args|
          assoc_rows = args[0] ? Query.new(args[0], use: @use, eager_loaders: @eager_loaders, query_logger: query_logger, measurements: measurements).run : []
          merge! assoc_rows, rows, *args[1..-1]
        }
        nil
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
        q = @scopes.reduce(q) { |acc, scope| scope.(acc) }
        q
      end
    end
  end
end
