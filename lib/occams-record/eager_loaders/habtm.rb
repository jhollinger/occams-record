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
        # TODO cache join table results
        raise 'TODO'
      end

      def merge!(assoc_rows, rows)
        # TODO look up key from cached join table results
      end
    end
  end
end
