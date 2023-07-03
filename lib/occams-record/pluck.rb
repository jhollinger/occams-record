module OccamsRecord
  module Pluck
    private

    def pluck_results(results, model: nil)
      casters = TypeCaster.generate(results.columns, results.column_types, model: model)
      if results[0]&.size == 1
        pluck_results_single(results, casters)
      else
        pluck_results_multi(results, casters)
      end
    end

    # returns an array of values
    def pluck_results_single(results, casters)
      col = results.columns[0]
      caster = casters[col]
      if caster
        results.map { |row|
          val = row[col]
          caster.(val)
        }
      else
        results.map { |row| row[col] }
      end
    end

    # returns an array of arrays
    def pluck_results_multi(results, casters)
      results.map { |row|
        row.map { |col, val|
          caster = casters[col]
          caster ? caster.(val) : val
        }
      }
    end
  end
end
