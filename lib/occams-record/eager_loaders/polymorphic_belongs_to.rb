module OccamsRecord
  module EagerLoaders
    # Eager loader for polymorphic belongs tos
    class PolymorphicBelongsTo
      # @return [String] association name
      attr_reader :name

      #
      # @param ref [ActiveRecord::Association] the ActiveRecord association
      # @param scope [Proc] a scope to apply to the query (optional). It will be passed an
      # ActiveRecord::Relation on which you may call all the normal query hethods (select, where, etc) as well as any scopes you've defined on the model.
      # @param use [Array<Module>] optional Module to include in the result class (single or array)
      # @param as [Symbol] Load the association usign a different attribute name
      # @yield perform eager loading on *this* association (optional)
      #
      def initialize(ref, scope = nil, use: nil, as: nil, &eval_block)
        @ref, @scope, @use, @eval_block = ref, scope, use, eval_block
        @name = (as || ref.name).to_s
        @foreign_type = @ref.foreign_type.to_sym
        @foreign_key = @ref.foreign_key.to_sym
      end

      #
      # Run the query and merge the results into the given rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @param query_logger [Array<String>]
      #
      def run(rows, query_logger: nil)
        query(rows) { |scope|
          assoc_rows = Query.new(scope, use: @use, query_logger: query_logger, &@eval_block).run
          merge! assoc_rows, rows
        }
      end

      private

      #
      # Yield ActiveRecord::Relations to the given block, one for every "type" represented in the given rows.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @yield
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
        q = @scope.(q) if @scope
        q
      end
    end
  end
end
