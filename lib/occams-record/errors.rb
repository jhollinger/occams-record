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
      @loader = record.class.eager_loader
    end

    # @return [String]
    def to_s
      message
    end

    private

    def load_chain(loader = @loader)
      return ['root'] if loader.nil?
      load_chain(loader.parent_loader) << loader.name
    end
  end

  # Exception when an unselected column is called on a result row
  class MissingColumnError < MissingDataError
    # @return [String]
    def message
      loads = load_chain.join(".")
      "Column '#{name}' is unavailable on #{model_name} because it was not included in the SELECT statement! Found at #{loads}"
    end
  end

  # Exception when an unloaded association is called on a result row
  class MissingEagerLoadError < MissingDataError
    # @return [String]
    def message
      loads = load_chain.join(".")
      "Association '#{name}' is unavailable on #{model_name} because it was not eager loaded! Found at #{loads}"
    end
  end

  # Exception when a requested record couldn't be found.
  class NotFound < StandardError
    # @return [String]
    attr_reader :model_name
    # @return [Hash]
    attr_reader :attrs

    # @param model_name [String]
    #
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
