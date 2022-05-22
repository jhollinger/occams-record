module OccamsRecord
  module Batches
    class Cursor
      module QueryHelpers
        def find_each_with_cursor(batch_size: 1000, use_transaction: true)
          enum = Enumerator.new { |y|
            cursor.open(use_transaction: use_transaction) { |c|
              c.each(batch_size: batch_size) { |record|
                y.yield record
              }
            }
          }
          if block_given?
            enum.each { |record| yield record }
          else
            enum
          end
        end

        def find_in_batches_with_cursor(batch_size: 1000, use_transaction: true)
          enum = Enumerator.new { |y|
            cursor.open(use_transaction: use_transaction) { |c|
              c.each_batch(batch_size: batch_size) { |batch|
                y.yield batch
              }
            }
          } 
          if block_given?
            enum.each { |batch| yield batch }
          else
            enum
          end
        end
      end
    end
  end
end
