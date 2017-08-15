module OccamsRecord
  module EagerLoaders
    #
    # Base class for eagoer loading an association.
    #
    class Base
      # @return [String] association name
      attr_reader :name
      # @return [Class] optional base class for results
      attr_reader :base_class
      # @return [Proc] optional Proc for eager loading things on this association
      attr_reader :eval_block

      #
      # @param ref [ActiveRecord::Association] the ActiveRecord association
      # @param scope [Proc] a scope to apply to the query (optional)
      # @param base_class [Class] optional base class for results
      # @param eval_block [Proc] a block where you may perform eager loading on *this* association (optional)
      #
      def initialize(ref, scope = nil, base_class = nil, &eval_block)
        @ref, @name, @model, @eval_block = ref, ref.name.to_s, ref.klass, eval_block
        @scope = scope ? ref.klass.instance_exec(&scope) : ref.klass.all
        @base_class = base_class
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
