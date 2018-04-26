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
        assoc_ids = join_rows(rows).map { |row| row[1] }.compact.uniq
        yield base_scope.where(@ref.association_primary_key => assoc_ids) if assoc_ids.any?
      end

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::Results::Row>] rows loaded from the association
      # @param rows [Array<OccamsRecord::Results::Row>] rows loaded from the main model
      #
      def merge!(assoc_rows, rows)
        joins_by_id = join_rows(rows).reduce({}) { |a, join|
          id = join[0].to_s
          a[id] ||= []
          a[id] << join[1].to_s
          a
        }

        assoc_order_cache = {} # maintains the original order of assoc_rows
        assoc_rows_by_id = assoc_rows.each_with_index.reduce({}) { |a, (row, idx)|
          begin
            id = row.send(@ref.association_primary_key).to_s
          rescue NoMethodError => e
            raise MissingColumnError.new(row, e.name)
          end
          assoc_order_cache[id] = idx
          a[id] = row
          a
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
      def join_rows(rows)
        return @join_rows if defined? @join_rows

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

        @join_rows = quoted_ids.any? ? conn.
          exec_query("SELECT #{fkey}, #{assoc_fkey} FROM #{join_table} WHERE #{fkey} IN (#{quoted_ids.join ','})").
          rows : []
      end
    end
  end
end
