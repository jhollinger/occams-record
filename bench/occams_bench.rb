require 'benchmark'

class OccamsBench
  Example = Struct.new(:label, :proc) do
    def measure
      self.proc.call # warm-up run
      Benchmark.realtime { self.proc.call }
    end
  end

  def initialize(title)
    @title = title
    @examples = []
  end

  def measure(label, &example)
    @examples << Example.new(label, example)
    self
  end

  def run
    "#{@title}\n" + @examples.map { |ex|
      time = ex.measure.round 8
      "  #{ex.label}\t#{time}"
    }.join("\n") + "\n\n"
  end
end
