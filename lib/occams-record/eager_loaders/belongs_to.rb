module OccamsRecord
  module EagerLoaders
    # Eager loader for belongs_to associations.
    class BelongsTo < Base
      private

      #
      # Yield one or more ActiveRecord::Relation objects to a given block.
      #
      # @param rows [Array<OccamsRecord::Results::Row>] Array of rows used to calculate the query.
      # @yield
      #
      def query(rows)
        ids = rows.map { |row|
          begin
            row.send @ref.foreign_key
          rescue NoMethodError => e
            raise MissingColumnError.new(row, e.name)
          end
        }.compact.uniq
        yield base_scope.where(@ref.active_record_primary_key => ids) if ids.any?
      end

      #
      # Merge the association rows into the given rows.
      #
      # @param assoc_rows [Array<OccamsRecord::Results::Row>] rows loaded from the association
      # @param rows [Array<OccamsRecord::Results::Row>] rows loaded from the main model
      #
      def merge!(assoc_rows, rows)
        Merge.new(rows, name).
          single!(assoc_rows, @ref.foreign_key.to_s, @model.primary_key.to_s)
      end
    end
  end
end
