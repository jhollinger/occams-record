module MicroRecord
  module EagerLoaders
    # Eager loader for has_many associations.
    class HasMany < HasOne
      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OpenStruct>] rows loaded from the association
      # @param rows [Array<OpenStruct>] rows loaded from the main model
      #
      def merge!(assoc_rows, rows)
        assoc_rows_by_fkey = assoc_rows.group_by(&@ref.foreign_key.to_sym)
        rows.each do |row|
          pkey = row[@ref.active_record_primary_key]
          row[name] = assoc_rows_by_fkey[pkey] || []
        end
      end
    end
  end
end
