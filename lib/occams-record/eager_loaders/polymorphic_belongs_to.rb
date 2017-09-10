module OccamsRecord
  module EagerLoaders
    # Eager loader for polymorphic belongs tos
    class PolymorphicBelongsTo
      # @return [String] association name
      attr_reader :name
      # @return [Array<Module>] optional Module to include in the result class (single or array)
      attr_reader :use
      # @return [Proc] optional Proc for eager loading things on this association
      attr_reader :eval_block

      #
      # @param ref [ActiveRecord::Association] the ActiveRecord association
      # @param scope [Proc] a scope to apply to the query (optional)
      # @param use [Array<Module>] optional Module to include in the result class (single or array)
      # @param eval_block [Proc] a block where you may perform eager loading on *this* association (optional)
      #
      def initialize(ref, scope = nil, use = nil, &eval_block)
        @ref, @name, @scope, @eval_block = ref, ref.name.to_s, scope, eval_block
        @foreign_type = @ref.foreign_type.to_sym
        @foreign_key = @ref.foreign_key.to_sym
        @use = use
      end

      #
      # Yield ActiveRecord::Relations to the given block, one for every "type" represented in the given rows.
      #
      # @param rows [Array<OccamsRecord::ResultRow>] Array of rows used to calculate the query.
      #
      def query(rows)
        rows_by_type = rows.group_by(&@foreign_type)
        rows_by_type.each do |type, rows_of_type|
          model = type.constantize
          ids = rows_of_type.map(&@foreign_key).uniq
          q = base_scope(model).where(model.primary_key => ids)
          yield q
        end
      end

      #
      # Merge associations of type N into rows of model N.
      #
      def merge!(assoc_rows_of_type, rows)
        return if assoc_rows_of_type.empty?
        type = assoc_rows_of_type[0].class.model_name
        rows_of_type = rows.select { |r| r.send(@foreign_type) == type }
        model = type.constantize
        Merge.new(rows_of_type, name).
          single!(assoc_rows_of_type, @ref.foreign_key.to_s, model.primary_key.to_s)
      end

      private

      def base_scope(model)
        q = model.all
        q = q.instance_exec(&@ref.scope) if @ref.scope
        q = q.instance_exec(&@scope) if @scope
        q
      end
    end
  end
end
