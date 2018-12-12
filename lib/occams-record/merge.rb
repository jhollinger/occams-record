module OccamsRecord
  #
  # Represents a merge operation to be performed. Merges are always "left" merges. You initialize the
  # Merge with the "left" records, and the name of the attribute into which "right" records will be placed.
  #
  # After initializing, perform a specific type of merge by calling the appropriate *! method.
  #
  class Merge
    # @return [Array<OccamsRecord::Results::Row>] the rows into which associated rows will be merged
    attr_reader :target_rows

    #
    # Initialize a new Merge operation.
    #
    # @param target_rows [Array<OccamsRecord::Results::Row] the rows into which associated rows should be merged
    # @param assoc_attr [String|Symbol] name of the attribute where associated rows will be put
    #
    def initialize(target_rows, assoc_attr)
      @target_rows = target_rows
      @assign = "#{assoc_attr}="
    end

    #
    # Merge a single assoc_row into each target_rows (or nil if one can't be found).
    # target_attr and assoc_attr are the matching keys on target_rows and assoc_rows, respectively.
    #
    # @param assoc_rows [Array<OccamsRecord::Results::Row>] rows to merge into target_rows
    # @param mapping [Hash] The fields that should match up. The keys are for the target rows and the values
    # for the associated rows.
    #
    def single!(assoc_rows, mapping)
      target_attrs = mapping.keys
      assoc_attrs = mapping.values

      assoc_rows_by_ids = assoc_rows.reduce({}) { |a, assoc_row|
        begin
          ids = assoc_attrs.map { |attr| assoc_row.send attr }
        rescue NoMethodError => e
          raise MissingColumnError.new(assoc_row, e.name)
        end
        a[ids] ||= assoc_row
        a
      }

      target_rows.each do |row|
        begin
          attrs = target_attrs.map { |attr| row.send attr }
        rescue NoMethodError => e
          raise MissingColumnError.new(row, e.name)
        end
        row.send @assign, attrs.any? ? assoc_rows_by_ids[attrs] : nil
      end
      nil
    end

    #
    # Merge an array of assoc_rows into the target_rows. Some target_rows may end up with 0 matching
    # associations, and they'll be assigned empty arrays.
    #
    # @param assoc_rows [Array<OccamsRecord::Results::Row>] rows to merge into target_rows
    # @param mapping [Hash] The fields that should match up. The keys are for the target rows and the values
    # for the associated rows.
    #
    def many!(assoc_rows, mapping)
      target_attrs = mapping.keys
      assoc_attrs = mapping.values

      begin
        assoc_rows_by_attrs = assoc_rows.group_by { |r|
          assoc_attrs.map { |attr| r.send attr }
        }
      rescue NoMethodError => e
        raise MissingColumnError.new(assoc_rows[0], e.name)
      end

      target_rows.each do |row|
        begin
          pkeys = target_attrs.map { |attr| row.send attr }
        rescue NoMethodError => e
          raise MissingColumnError.new(row, e.name)
        end
        row.send @assign, assoc_rows_by_attrs[pkeys] || []
      end
      nil
    end
  end
end
