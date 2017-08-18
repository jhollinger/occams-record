module OccamsRecord
  module EagerLoaders
    # Eager loader for has_one associations.
    class HasOne < Base
      #
      # Yield one or more ActiveRecord::Relation objects to a given block.
      #
      # @param rows [Array<OccamsRecord::ResultRow>] Array of rows used to calculate the query.
      #
      def query(rows)
        ids = rows.map { |r| r.send @ref.active_record_primary_key }.compact.uniq
        q = base_scope.where(@ref.foreign_key => ids)
        q.where!(@ref.type => rows[0].class.try!(:model_name)) if @ref.options[:as]
        yield q
      end

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::ResultRow>] rows loaded from the association
      # @param rows [Array<OccamsRecord::ResultRow>] rows loaded from the main model
      #
      def merge!(assoc_rows, rows)
        fkey_col = @ref.foreign_key.to_s
        assoc_rows_by_fkey = assoc_rows.reduce({}) { |a, assoc_row|
          fid = assoc_row.send fkey_col
          a[fid] = assoc_row
          a
        }

        pkey_col = @ref.active_record_primary_key.to_s
        rows.each do |row|
          pkey = row.send pkey_col
          row.send @assign, pkey ? assoc_rows_by_fkey[pkey] : nil
        end
      end
    end
  end
end
