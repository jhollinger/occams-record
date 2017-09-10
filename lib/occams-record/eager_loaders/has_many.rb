module OccamsRecord
  module EagerLoaders
    # Eager loader for has_many associations.
    class HasMany < HasOne
      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::ResultRow>] rows loaded from the association
      # @param rows [Array<OccamsRecord::ResultRow>] rows loaded from the main model
      #
      def merge!(assoc_rows, rows)
        Merge.new(rows, name).
          many!(assoc_rows, @ref.active_record_primary_key, @ref.foreign_key)
      end
    end
  end
end
