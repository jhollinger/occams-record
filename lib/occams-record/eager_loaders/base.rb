module OccamsRecord
  module EagerLoaders
    #
    # Base class for eagoer loading an association.
    #
    class Base
      # @return [String] association name
      attr_reader :name
      # @return [Array<Module>] optional Module to include in the result class (single or array)
      attr_reader :use
      # @return [Proc] optional Proc for eager loading things on this association
      attr_reader :eval_block

      #
      # @param ref [ActiveRecord::Association] the ActiveRecord association
      # @param scope [Proc] a scope to apply to the query (optional)
      # @param use [Array(Module)] optional Module to include in the result class (single or array)
      # @param eval_block [Proc] a block where you may perform eager loading on *this* association (optional)
      #
      def initialize(ref, scope = nil, use = nil, &eval_block)
        @ref, @scope, @use, @eval_block = ref, scope, use, eval_block
        @name, @model = ref.name.to_s, ref.klass
      end

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

      private

      #
      # Returns the base scope for the relation, including any scope defined on the association itself,
      # and any optional scope passed into the eager loader.
      #
      # @return [ActiveRecord::Relation]
      #
      def base_scope
        q = @ref.klass.all
        q = q.instance_exec(&@ref.scope) if @ref.scope
        q = q.instance_exec(&@scope) if @scope
        q
      end
    end
  end
end
