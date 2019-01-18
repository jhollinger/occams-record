module OccamsRecord
  # Exception raised when a record wasn't loaded with all requested data
  class MissingDataError < StandardError
    # @return [String]
    attr_reader :model_name
    # @return [OccamsRecord::Result::Row]
    attr_reader :record
    # @return [Symbol]
    attr_reader :name

    # @param record [OccamsRecord::Result::Row]
    # @param name [Symbol]
    def initialize(record, name)
      @record, @name = record, name
      @model_name = record.class.model_name
    end

    # @return [String]
    def to_s
      message
    end
  end

  # Exception when an unselected column is called on a result row
  class MissingColumnError < MissingDataError
    # @return [String]
    def message
      "Column '#{name}' is unavailable on #{model_name} because it was not included in the SELECT statement!"
    end
  end

  # Exception when an unloaded association is called on a result row
  class MissingEagerLoadError < MissingDataError
    # @return [String]
    def message
      "Association '#{name}' is unavailable on #{model_name} because it was not eager loaded!"
    end
  end

  # Exception when a requested record couldn't be found.
  class NotFound < StandardError
    # @return [String]
    attr_reader :model_name
    # @return [Hash]
    attr_reader :attrs

    # @param model_name [String]
    # @param attrs [Hash]
    def initialize(model_name, attrs)
      @model_name, @attrs = model_name, attrs
    end

    # @return [String]
    def to_s
      message
    end

    # @return [String]
    def message
      "#{model_name} could not be found with #{attrs}!"
    end
  end
end
