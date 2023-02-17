module OccamsRecord
  module EagerLoaders
    # A low-memory way to trace the path of eager loads from any point back to the root query
    Tracer = Struct.new(:name, :parent, :through) do
      def to_s
        lookup.join(".")
      end

      def lookup(trace = self)
        return [] if trace.nil?
        name = trace.through ? "through(#{trace.name})" : trace.name
        lookup(trace.parent) << name
      end
    end
  end
end
