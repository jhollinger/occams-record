module OccamsRecord
  module Batches
    module OffsetLimit
      #
      # Implements batched loading for pure SQL.
      #
      class RawQuery
        def initialize(conn, sql, binds, use: nil, query_logger: nil, eager_loaders: nil)
          @conn, @sql, @binds = conn, sql, binds
          @use, @query_logger, @eager_loaders = use, query_logger, eager_loaders

          unless binds.is_a? Hash
            raise ArgumentError, "When using find_each/find_in_batches with raw SQL, binds MUST be a Hash. SQL statement: #{@sql}"
          end

          unless @sql =~ /LIMIT\s+%\{batch_limit\}/i and @sql =~ /OFFSET\s+%\{batch_offset\}/i
            raise ArgumentError, "When using find_each/find_in_batches with raw SQL, you must specify 'LIMIT %{batch_limit} OFFSET %{batch_offset}'. SQL statement: #{@sql}"
          end
        end

        #
        # Returns an Enumerator that yields batches of records, of size "of".
        # The SQL string must include 'LIMIT %{batch_limit} OFFSET %{batch_offset}'.
        # The bind values will be provided by OccamsRecord.
        #
        # @param batch_size [Integer] batch size
        # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
        # @return [Enumerator] yields batches
        #
        def enum(batch_size:, use_transaction: true)
          Enumerator.new do |y|
            if use_transaction and @conn.open_transactions == 0
              @conn.transaction {
                run_batches y, batch_size
              }
            else
              run_batches y, batch_size
            end
          end
        end

        private

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
