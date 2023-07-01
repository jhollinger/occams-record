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
        results.map { |r|
          val = r[col]
          enum.has_key?(val) ? val : inv_enum[val]
        }
      else
        # micro-optimization for when there are no enums
        results.map { |r| r[col] }
      end
    end

    # returns an array of arrays
    def pluck_results_multi(results, cols, model: nil)
      any_enums = false
      cols_with_enums = cols.map { |col|
        enum = model&.defined_enums&.[](col)
        any_enums ||= !!enum
        [col, enum, enum&.invert]
      }

      if any_enums
        results.map { |row|
          cols_with_enums.map { |(col, enum, inv_enum)|
            if enum
              val = row[col]
              enum.has_key?(val) ? val : inv_enum[val]
            else
              row[col]
            end
          }
        }
      else
        # micro-optimization for when there are no enums
        results.map { |row|
          cols.map { |col| row[col] }
        }
      end
    end
  end
end
