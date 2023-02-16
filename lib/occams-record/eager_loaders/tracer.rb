module OccamsRecord
  module EagerLoaders
    # A low-memory way to trace the path of eager loads from any point back to the root query
    Tracer = Struct.new(:name, :parent) do
      def to_s
        lookup.join(".")
      end

      def lookup(trace = self)
        return [] if trace.nil?
        lookup(trace.parent) << trace.name
      end
    end
  end
end
