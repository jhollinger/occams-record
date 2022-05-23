module OccamsRecord
  module Batches
    module Cursor
      module QueryHelpers
        #
        # Loads records in batches of N and yields each record to a block (if given). If no block is given,
        # returns an Enumerator.
        #
        # NOTE Unlike find_each, batches are loaded using a cursor, which offers better performance.
        # Postgres only. See the docs for OccamsRecord::Cursor for more details.
        #
        # @param batch_size [Integer] fetch this many rows at once
        # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
        # @yield [OccamsRecord::Results::Row]
        # @return [Enumerator] will yield each record
        #
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

        #
        # Loads records in batches of N and yields each batch to a block (if given). If no block is given,
        # returns an Enumerator.
        #
        # NOTE Unlike find_in_batches, batches are loaded using a cursor, which offers better performance.
        # Postgres only. See the docs for OccamsRecord::Cursor for more details.
        #
        # @param batch_size [Integer] fetch this many rows at once
        # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
        # @yield [OccamsRecord::Results::Row]
        # @return [Enumerator] will yield each record
        #
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
