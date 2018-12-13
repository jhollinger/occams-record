require 'benchmark'
require 'memory_profiler'

class OccamsBench
  Result = Struct.new(:label, :measurement)

  def initialize(title)
    @title = title
  end

  def active_record(&example)
    @active_record = example
    self
  end

  def occams_record(&example)
    @occams_record = example
    self
  end

  def speed
    run "sec" do |ex|
      ex.call # warm-up run
      Benchmark.realtime { ex.call }
    end
  end

  def memory
    run "bytes" do |ex|
      report = MemoryProfiler.report { ex.call }
      report.total_allocated_memsize
    end
  end

  private

  def run(units)
    ar_result = yield @active_record
    or_result = yield @occams_record

    incr = or_result - ar_result
    p_incr = (incr / or_result.to_f) * 100 * -1

    %(
#{@title}
  ActiveRecord #{ar_result.round 8} #{units}
  OccamsRecord #{or_result.round 8} #{units}
  #{p_incr.round}% improvement
    ).strip + "\n\n"
  end
end
