module OccamsRecord
  module Pluck
    private

    def pluck_results(results, cols, model: nil)
      # when we're returning 1 column per result
      if cols.size == 1
        col = cols[0].to_s
        enum = model&.defined_enums&.[](col)
        inv_enum = enum&.invert
        if enum
          results.map { |r|
            val = r[col]
            enum.has_key?(val) ? val : inv_enum[val]
          }
        else
          results.map { |r| r[col] }
        end
      # an array of columns per result
      else
        cols = cols.map { |col|
          col = col.to_s
          enum = model&.defined_enums&.[](col)
          [col, enum, enum&.invert]
        }
        results.map { |row|
          cols.map { |(col, enum, inv_enum)|
            if enum
              val = row[col]
              enum.has_key?(val) ? val : inv_enum[val]
            else
              row[col]
            end
          }
        }
      end
    end
  end
end
