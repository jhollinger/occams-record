module MicroRecord
  module EagerLoaders
    # Eager loader for polymorphic belongs tos
    class PolymorphicBelongsTo
      # @return [String] association name
      attr_reader :name
      # @return [Proc] optional Proc for eager loading things on this association
      attr_reader :eval_block

      def initialize(ref, scope = nil, &eval_block)
        @ref, @name, @scope, @eval_block = ref, ref.name.to_s, scope, eval_block
        @foreign_type = @ref.foreign_type.to_sym
        @foreign_key = @ref.foreign_key.to_sym
        @assign = "#{@name}="
      end

      #
      # Return an array of ActiveRecord::Relations, one for each "type" found in "rows."
      # The relation will simply query the model by whatever primary keys for that type are in "rows."
      #
      def query(rows)
        rows_by_type = rows.group_by(&@foreign_type)
        rows_by_type.each do |type, rows_of_type|
          model = type.constantize
          ids = rows_of_type.map(&@foreign_key).uniq
          q = model.where(model.primary_key => ids)
          yield @scope ? @scope.(q) : q
        end
      end

      #
      # Merge associations of type N into rows of model N.
      #
      def merge!(assoc_rows_of_type, rows)
        type = assoc_rows_of_type[0].class.try!(:model_name) || return
        rows_of_type = rows.select { |r| r.send(@foreign_type) == type }
        merge_model!(assoc_rows_of_type, rows_of_type, type.constantize)
      end

      private

      def merge_model!(assoc_rows, rows, model)
        pkey_col = model.primary_key.to_s
        assoc_rows_by_id = assoc_rows.reduce({}) { |a, assoc_row|
          id = assoc_row.send pkey_col
          a[id] = assoc_row
          a
        }

        rows.each do |row|
          fkey = row.send @ref.foreign_key
          row.send @assign, fkey ? assoc_rows_by_id[fkey] : nil
        end
      end
    end
  end
end
