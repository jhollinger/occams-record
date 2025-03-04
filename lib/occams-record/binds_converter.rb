module OccamsRecord
  #
  # Classes and methods for converting from Rails-style binds (?, :foo) to native Ruby format (%s, %{foo}).
  #
  module BindsConverter
    #
    # Convert any Rails-style binds (?, :foo) to native Ruby format (%s, %{foo}).
    #
    # @param sql [String]
    # @param binds [Hash|Array]
    # @return [String] the converted SQL string
    #
    def self.convert(sql, binds)
      converter =
        case binds
        when Hash then Named.new(sql, binds)
        when Array then Positional.new(sql, binds)
        else raise ArgumentError, "OccamsRecord: Unsupported SQL bind params '#{binds.inspect}'. Only Hash and Array are supported"
        end
      converter.to_s
    end
  end
end
