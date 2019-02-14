module OccamsRecord
  Measurements = Struct.new(:total_time, :queries)
  Measurement = Struct.new(:table_name, :sql, :time)

  #
  # Measure the time each query takes. Useful for figuring out which query is the slow one when you're doing a bunch of eager loads.
  #
  # orders = OccamsRecord.
  #   query(Order.all).
  #   eager_load(:customer).
  #   ...
  #   measure { |x|
  #     puts "Total time: #{x.total_time} sec"
  #     x.queries.each { |q|
  #       puts "Table: #{q.table_name} (#{q.time} sec)"
  #       puts q.sql
  #     }
  #   }.
  #   run
  #
  module Measureable
    #
    # Track the run time of each query, and the total run time of everything combined.
    #
    # @yield [OccamsRecord::Measurements]
    # @return self
    #
    def measure(&block)
      @measurements ||= []
      @measurement_results_block = block
      self
    end

    private

    def measure?
      !@measurements.nil?
    end

    def measure!(table_name, sql)
      result = nil
      time = Benchmark.realtime { result = yield }
      @measurements << Measurement.new(table_name, sql, time)
      result
    end

    def record_start_time!
      @start_time = Time.now if top_level_measurer?
    end

    def yield_measurements!
      if top_level_measurer?
        total_time = Time.now - @start_time
        measurements = Measurements.new(total_time, @measurements.sort_by(&:time))
        @measurement_results_block.call(measurements)
      end
    end

    def top_level_measurer?
      defined?(@measurement_results_block) && !@measurement_results_block.nil?
    end
  end
end
