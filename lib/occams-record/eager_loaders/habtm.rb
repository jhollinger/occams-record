module OccamsRecord
  module EagerLoaders
    # Eager loader for has_and_belongs_to_many associations.
    class Habtm < Base
      private

      #
      # Yield one or more ActiveRecord::Relation objects to a given block.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @yield
      #
      def query(rows)
        join_rows = fetch_join_rows(rows)
        assoc_ids = join_rows.map { |row| row[1] }.compact.uniq
        yield assoc_ids.any? ? base_scope.where(@ref.association_primary_key => assoc_ids) : nil, join_rows
      end

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::Results::Row>] rows loaded from the association
      # @param rows [Array<OccamsRecord::Results::Row>] rows loaded from the main model
      # @param join_rows [Array<Array<String>>] raw join'd ids from the db
      #
      def merge!(assoc_rows, rows, join_rows)
        joins_by_id = join_rows.each_with_object({}) { |join, acc|
          id = join[0].to_s
          acc[id] ||= []
          acc[id] << join[1].to_s
        }

        assoc_order_cache = {} # maintains the original order of assoc_rows
        assoc_rows_by_id = assoc_rows.each_with_index.each_with_object({}) { |(row, idx), acc|
          begin
            id = row.send(@ref.association_primary_key).to_s
          rescue NoMethodError => e
            raise MissingColumnError.new(row, e.name)
          end
          assoc_order_cache[id] = idx
          acc[id] = row
        }

        assign = "#{name}="
        rows.each do |row|
          begin
            id = row.send(@ref.active_record_primary_key).to_s
          rescue NoMethodError => e
            raise MissingColumnError.new(row, e.name)
          end
          assoc_fkeys = (joins_by_id[id] || []).uniq.
            sort_by { |fkey| assoc_order_cache[fkey] || 0 }

          associations = assoc_rows_by_id.values_at(*assoc_fkeys).compact.uniq
          row.send assign, associations
        end
      end

      private

      #
      # Fetches (and caches) an array of rows from the join table. The rows are [fkey, assoc_fkey].
      #
      # @param rows [Array<OccamsRecord::Results::Row>]
      # @return [Array<Array<String>>]
      #
      def fetch_join_rows(rows)
        conn = @model.connection
        join_table = conn.quote_table_name @ref.join_table
        assoc_fkey = conn.quote_column_name @ref.association_foreign_key
        fkey = conn.quote_column_name @ref.foreign_key
        quoted_ids = rows.map { |row|
          begin
            id = row.send @ref.active_record_primary_key
          rescue NoMethodError => e
            raise MissingColumnError.new(row, e.name)
          end
          conn.quote id
        }

        quoted_ids.any? ? conn.
          exec_query("SELECT #{fkey}, #{assoc_fkey} FROM #{join_table} WHERE #{fkey} IN (#{quoted_ids.join ','})").
          rows : []
      end
    end
  end
end
