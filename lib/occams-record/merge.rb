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
    # @param target_attr [String|Symbol] name of the matching key on the target records
    # @param assoc_attr [String] name of the matching key on the associated records
    #
    def single!(assoc_rows, target_attr, assoc_attr)
      assoc_rows_by_id = assoc_rows.reduce({}) { |a, assoc_row|
        begin
          id = assoc_row.send assoc_attr
        rescue NoMethodError => e
          raise MissingColumnError.new(assoc_row, e.name)
        end
        a[id] ||= assoc_row
        a
      }

      target_rows.each do |row|
        begin
          attr = row.send target_attr
        rescue NoMethodError => e
          raise MissingColumnError.new(row, e.name)
        end
        row.send @assign, attr ? assoc_rows_by_id[attr] : nil
      end
    end

    #
    # Merge an array of assoc_rows into the target_rows. Some target_rows may end up with 0 matching
    # associations, and they'll be assigned empty arrays.
    # target_attr and assoc_attr are the matching keys on target_rows and assoc_rows, respectively.
    #
    def many!(assoc_rows, target_attr, assoc_attr)
      begin
        assoc_rows_by_attr = assoc_rows.group_by(&assoc_attr.to_sym)
      rescue NoMethodError => e
        raise MissingColumnError.new(assoc_rows[0], e.name)
      end

      target_rows.each do |row|
        begin
          pkey = row.send target_attr
        rescue NoMethodError => e
          raise MissingColumnError.new(row, e.name)
        end
        row.send @assign, assoc_rows_by_attr[pkey] || []
      end
    end
  end
end
