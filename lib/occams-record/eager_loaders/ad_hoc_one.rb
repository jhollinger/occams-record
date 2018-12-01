module OccamsRecord
  module EagerLoaders
    #
    # Eager loader for an ad hoc association of 0 or 1 records (like belongs_to or has_one).
    #
    class AdHocOne < AdHocBase
      private

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::Results::Row>] rows loaded from the associated table
      # @param rows [Array<OccamsRecord::Results::Row>] rows loaded from the main table
      #
      def merge!(assoc_rows, rows)
        Merge.new(rows, name).
          single!(assoc_rows, @mapping)
      end
    end
  end
end
