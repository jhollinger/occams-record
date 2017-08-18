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
        table_name = @ref.active_record.table_name
        pkey = @ref.active_record_primary_key

        ids = rows.map { |r| r.send @ref.active_record_primary_key }.compact.uniq
        q = base_scope.where("#{table_name}.#{pkey}" => ids)
        yield q
        # TODO cache join table results
      end

      def merge!(assoc_rows, rows)
        # TODO look up key from cached join table results
      end

      private

      def base_scope
        conn = @model.connection
        join_table = conn.quote_table_name @ref.join_table
        assoc_fkey = conn.quote_column_name @ref.association_foreign_key
        assoc_pkey = conn.quote_table_name @ref.association_primary_key

        table_name = @ref.active_record.quoted_table_name
        pkey = conn.quote_column_name @ref.active_record_primary_key
        fkey = conn.quote_column_name @ref.foreign_key

        super.
          joins("INNER JOIN #{join_table} ON #{join_table}.#{assoc_fkey} = #{@ref.quoted_table_name}.#{assoc_pkey}").
          joins("INNER JOIN #{table_name} ON #{table_name}.#{pkey} = #{join_table}.#{fkey}")
      end
    end
  end
end
