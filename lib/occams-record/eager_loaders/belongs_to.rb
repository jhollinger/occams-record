module OccamsRecord
  module EagerLoaders
    # Eager loader for belongs_to associations.
    class BelongsTo < Base
      #
      # Yield one or more ActiveRecord::Relation objects to a given block.
      #
      # @param rows [Array<OccamsRecord::ResultRow>] Array of rows used to calculate the query.
      #
      def query(rows)
        ids = rows.map { |r| r.send @ref.foreign_key }.compact.uniq
        yield base_scope.where(@ref.active_record_primary_key => ids)
      end

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::ResultRow>] rows loaded from the association
      # @param rows [Array<OccamsRecord::ResultRow>] rows loaded from the main model
      #
      def merge!(assoc_rows, rows)
        pkey_col = @model.primary_key.to_s
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
