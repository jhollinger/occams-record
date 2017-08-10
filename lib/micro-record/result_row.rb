module MicroRecord
  # ActiveRecord's internal type casting API changes from version to version.
  TYPE_CAST_METHOD = case ActiveRecord::VERSION::MAJOR
                     when 4 then :type_cast_from_database
                     when 5 then :deserialize
                     end

  #
  # Dynamically build a class for a specific set of result rows. It will inherit from MicroRecord::ResultRow.
  #
  # @param model [ActiveRecord::Base] the AR model representing the table (it holds column & type info).
  # @param column_names [Array<String>] the column names in the result set. The order MUST match the order returned by the query.
  # @param association_names [Array<String>] names of associations that will be eager loaded into the results.
  def self.build_result_row_class(model, column_names, association_names)
    Class.new(ResultRow) do
      self.columns = column_names.map(&:to_sym)

      # Build getters & setters for associations. (We need setters b/c they're set AFTER the row is initialized
      attr_accessor *association_names

      # Build a getter for each attribute returned by the query. The values will be type converted on demand.
      column_names.each_with_index do |col_name, idx|
        type = model.attributes_builder.types[col_name.to_s] || raise("MicroRecord: Column `#{col_name}` does not exist on model `#{model.name}`")
        define_method col_name do
          @cast_values_cache[idx] ||= type.send(TYPE_CAST_METHOD, @values[idx])
        end
      end
    end
  end

  #
  # Abstract class for result rows.
  #
  class ResultRow
    class << self
      # Array of column names in the row
      attr_accessor :columns
    end
    self.columns = []

    #
    # Initialize a new result row.
    #
    # @param raw_values [Array] array of raw values from db
    #
    def initialize(raw_values)
      @values = raw_values
      @cast_values_cache = {}
    end

    #
    # Return row as a Hash.
    #
    # @return [Hash] a Hash with Symbol keys
    def to_h
      self.class.columns.reduce({}) { |a, col_name|
        a[col_name] = send col_name
        a
      }
    end

    alias_method :to_hash, :to_h
  end
end
