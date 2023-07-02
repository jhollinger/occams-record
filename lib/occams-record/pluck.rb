module OccamsRecord
  module Pluck
    private

    def pluck_results(results, cols, model: nil)
      if cols.size == 1
        pluck_results_single(results, cols[0].to_s, model: model)
      else
        pluck_results_multi(results, cols.map(&:to_s), model: model)
      end
    end

    # returns an array of values
    def pluck_results_single(results, col, model: nil)
      casters = TypeCaster.generate(results.columns, results.column_types, model: model)
      col = results.columns[0]
      caster = casters[col]
      results.map { |row|
        val = row[col]
        caster ? caster.(val) : val
      }
    end

    # returns an array of arrays
    def pluck_results_multi(results, cols, model: nil)
      casters = TypeCaster.generate(results.columns, results.column_types, model: model)
      results.map { |row|
        row.map { |col, val|
          caster = casters[col]
          caster ? caster.(val) : val
        }
      }
    end
  end
end
