module OccamsRecord
  module EagerLoaders
    # Eager loader for has_and_belongs_to_many associations.
    class Habtm < Base
      #
      # Yield one or more ActiveRecord::Relation objects to a given block.
      #
      # @param rows [Array<OccamsRecord::ResultRow>] Array of rows used to calculate the query.
      #
      def query(rows)
        assoc_ids = join_rows(rows).map { |row| row[1] }.compact.uniq
        yield base_scope.where(@ref.association_primary_key => assoc_ids)
      end

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::ResultRow>] rows loaded from the association
      # @param rows [Array<OccamsRecord::ResultRow>] rows loaded from the main model
      #
      def merge!(assoc_rows, rows)
        joins_by_id = join_rows(rows).reduce({}) { |a, join|
          id = join[0].to_s
          a[id] ||= []
          a[id] << join[1].to_s
          a
        }

        assoc_rows_by_id = assoc_rows.reduce({}) { |a, row|
          id = row.send(@ref.association_primary_key).to_s
          a[id] = row
          a
        }

        rows.each do |row|
          id = row.send(@ref.active_record_primary_key).to_s
          assoc_fkeys = (joins_by_id[id] || []).uniq
          associations = assoc_rows_by_id.values_at(*assoc_fkeys).compact.uniq
          row.send @assign, associations
        end
      end

      private

      #
      # Fetches (and caches) an array of rows from the join table. The rows are [fkey, assoc_fkey].
      #
      # @param rows [Array<OccamsRecord::ResultRow>]
      # @return [Array<Array<String>>]
      #
      def join_rows(rows)
        return @join_rows if defined? @join_rows

        conn = @model.connection
        join_table = conn.quote_table_name @ref.join_table
        assoc_fkey = conn.quote_column_name @ref.association_foreign_key
        fkey = conn.quote_column_name @ref.foreign_key
        quoted_ids = rows.map { |r| conn.quote r.send @ref.active_record_primary_key }

        @join_rows = conn.
          exec_query("SELECT #{fkey}, #{assoc_fkey} FROM #{join_table} WHERE #{fkey} IN (#{quoted_ids.join ','})").
          rows
      end
    end
  end
end
