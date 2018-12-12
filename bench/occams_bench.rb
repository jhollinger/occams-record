require 'benchmark'

class OccamsBench
  Example = Struct.new(:label, :proc) do
    def run
      self.proc.call # warm-up run
      time = Benchmark.realtime { self.proc.call }
      Result.new(self.label, time)
    end
  end

  Result = Struct.new(:label, :time)

  def initialize(title)
    @title = title
    @examples = []
  end

  def measure(label, &example)
    @examples << Example.new(label, example)
    self
  end

  def run
    results = @examples.map(&:run)
    incr = results[1].time - results[0].time
    p_incr = (incr / results[1].time) * 100 * -1

    "#{@title}\n" + results.map { |result|
      "  #{result.label}\t#{result.time.round 8}"
    }.join("\n") +
    "\n  #{p_incr.round}% improvement" +
    "\n\n"
  end
end
