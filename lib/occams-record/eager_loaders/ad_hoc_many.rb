module OccamsRecord
  module EagerLoaders
    #
    # Eager loader for an ad hoc association of 0 or many records (like has_many).
    #
    class AdHocMany < AdHocBase
      private

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::Results::Row>] rows loaded from the associated table
      # @param rows [Array<OccamsRecord::Results::Row>] rows loaded from the main table
      #
      def merge!(assoc_rows, rows)
        Merge.new(rows, name).
          many!(assoc_rows, @mapping)
      end
    end
  end
end
