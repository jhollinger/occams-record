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
      enum = model&.defined_enums&.[](col)
      inv_enum = enum&.invert
      if enum
        results.map { |row|
          val = row.values[0]
          enum.has_key?(val) ? val : inv_enum[val]
        }
      else
        # micro-optimization for when there are no enums
        results.map { |row| row.values[0] }
      end
    end

    # returns an array of arrays
    def pluck_results_multi(results, cols, model: nil)
      any_enums = false
      cols_with_enums = cols.each_with_index.map { |col, idx|
        enum = model&.defined_enums&.[](col)
        any_enums ||= !!enum
        [idx, enum, enum&.invert]
      }

      if any_enums
        results.map { |row|
          values = row.values
          cols_with_enums.map { |(idx, enum, inv_enum)|
            if enum
              val = values[idx]
              enum.has_key?(val) ? val : inv_enum[val]
            else
              values[idx]
            end
          }
        }
      else
        # micro-optimization for when there are no enums
        results.map { |row|
          values = row.values
          cols.each_with_index.map { |_col, idx| values[idx] }
        }
      end
    end
  end
end
