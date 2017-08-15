module OccamsRecord
  module EagerLoaders
    # Eager loader for has_and_belongs_to_many associations.
    class Habtm < Base
      #
      # Return the SQL to load the association.
      #
      # @param primary_keys [String] Array of primary keys to search for.
      # @return [ActiveRecord::Relation]
      #
      def query(primary_keys)
        # TODO cache join table results
        raise 'TODO'
      end

      def merge!(assoc_rows, rows)
        # TODO look up key from cached join table results
      end
    end
  end
end
