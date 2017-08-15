module OccamsRecord
  module EagerLoaders
    #
    # Base class for eagoer loading an association.
    #
    class Base
      # @return [String] association name
      attr_reader :name
      # @return [Module] optional Module to include in the result class
      attr_reader :use
      # @return [Proc] optional Proc for eager loading things on this association
      attr_reader :eval_block

      #
      # @param ref [ActiveRecord::Association] the ActiveRecord association
      # @param scope [Proc] a scope to apply to the query (optional)
      # @param use [Module] optional Module to include in the result class
      # @param eval_block [Proc] a block where you may perform eager loading on *this* association (optional)
      #
      def initialize(ref, scope = nil, use = nil, &eval_block)
        @ref, @name, @model, @eval_block = ref, ref.name.to_s, ref.klass, eval_block
        @scope = scope ? ref.klass.instance_exec(&scope) : ref.klass.all
        @use = use
        @assign = "#{@name}="
      end

      #
      # Return the SQL to load the association.
      #
      # @return [ActiveRecord::Relation]
      #
      def query(rows)
        raise 'Not Implemented'
      end

      def merge!(assoc_rows, rows)
        raise 'Not Implemented'
      end
    end
  end
end
