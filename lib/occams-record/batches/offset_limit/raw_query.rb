module OccamsRecord
  module Batches
    module OffsetLimit
      #
      # Helpers for OFFSET/LIMIT based batches using raw SQL.
      #
      # Requires @sql, @binds, @query_logger, and @eager_loaders
      #
      module RawQuery
        #
        # Load records in batches of N and yield each record to a block if given. If no block is given,
        # returns an Enumerator.
        #
        # NOTE Unlike ActiveRecord's find_each, ORDER BY is respected. The primary key will be appended
        # to the ORDER BY clause to help ensure consistent batches. Additionally, it will be run inside
        # of a transaction.
        #
        # @param batch_size [Integer]
        # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
        # @yield [OccamsRecord::Results::Row]
        # @return [Enumerator] will yield each record
        #
        def find_each(batch_size: 1000, use_transaction: true)
          enum = Enumerator.new { |y|
            batches(of: batch_size, use_transaction: use_transaction).each { |batch|
              batch.each { |record| y.yield record }
            }
          }
          if block_given?
            enum.each { |record| yield record }
          else
            enum
          end
        end

        #
        # Load records in batches of N and yield each batch to a block if given.
        # If no block is given, returns an Enumerator.
        #
        # NOTE Unlike ActiveRecord's find_each, ORDER BY is respected. The primary key will be appended
        # to the ORDER BY clause to help ensure consistent batches. Additionally, it will be run inside
        # of a transaction.
        #
        # @param batch_size [Integer]
        # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
        # @yield [OccamsRecord::Results::Row]
        # @return [Enumerator] will yield each batch
        #
        def find_in_batches(batch_size: 1000, use_transaction: true)
          enum = batches(of: batch_size, use_transaction: use_transaction)
          if block_given?
            enum.each { |batch| yield batch }
          else
            enum
          end
        end

        private

        #
        # Returns an Enumerator that yields batches of records, of size "of".
        # The SQL string must include 'LIMIT %{batch_limit} OFFSET %{batch_offset}'.
        # The bind values will be provided by OccamsRecord.
        #
        # @param of [Integer] batch size
        # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
        # @return [Enumerator] yields batches
        #
        def batches(of:, use_transaction: true)
          unless @sql =~ /LIMIT\s+%\{batch_limit\}/i and @sql =~ /OFFSET\s+%\{batch_offset\}/i
            raise ArgumentError, "When using find_each/find_in_batches you must specify 'LIMIT %{batch_limit} OFFSET %{batch_offset}'. SQL statement: #{@sql}"
          end

          Enumerator.new do |y|
            if use_transaction and conn.open_transactions == 0
              conn.transaction {
                run_batches y, of
              }
            else
              run_batches y, of
            end
          end
        end

        def run_batches(y, of)
          offset = 0
          loop do
            results = ::OccamsRecord::RawQuery.new(@sql, @binds.merge({
              batch_limit: of,
              batch_offset: offset,
            }), use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders).run

            y.yield results if results.any?
            break if results.size < of
            offset += results.size
          end
        end
      end
    end
  end
end
