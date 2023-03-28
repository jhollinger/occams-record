module OccamsRecord
  module Pluck
    private

    def pluck_results(results, cols)
      if cols.size == 1
        col = cols[0].to_s
        results.map { |r| r[col] }
      else
        cols = cols.map(&:to_s)
        results.map { |r| r.values_at(*cols) }
      end
    end
  end
end
