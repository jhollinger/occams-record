require 'securerandom'

module OccamsRecord
  module Batches
    class Cursor
      DECLARE = "DECLARE %{name} %{scroll} CURSOR %{hold} FOR %{query}".freeze
      FETCH = "FETCH FORWARD %{num} FROM %{name}".freeze
      CLOSE = "CLOSE %{name}".freeze

      attr_reader :conn

      def initialize(conn, sql, name: nil, hold: false, use: nil, query_logger: nil, eager_loaders: nil)
        @conn, @sql, @hold = conn, sql, hold
        @quoted_name = conn.quote_table_name(name || "occams_cursor_#{SecureRandom.hex 4}")
        @use, @query_logger, @eager_loaders = use, query_logger, eager_loaders
      end

      def enum(batch_size:, use_transaction: true)
        Enumerator.new do |y|
          if use_transaction and conn.open_transactions == 0
            conn.transaction {
              run_batches y, batch_size
            }
          else
            run_batches y, batch_size
          end
        end
      end

      private

      def run_batches(y, of)
        ex = nil
        conn.execute DECLARE % {
          name: @quoted_name,
          scroll: "NO SCROLL",
          hold: @hold ? "WITH HOLD" : "WITHOUT HOLD",
          query: @sql,
        }

        out_of_records = false
        until out_of_records
          results = ::OccamsRecord::RawQuery.new(FETCH % {num: of, name: @quoted_name}, {},
            use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders).run
          y.yield results if results.any?
          out_of_records = results.size < of
        end
      rescue => e
        ex = e
        raise ex
      ensure
        begin
          conn.execute CLOSE % {name: @quoted_name}
        rescue => e
          # Don't let an error from CLOSE (like a dead transaction) hide what lead to the error with CLOSE (like bad SQL that raised an error and aborted the transaction)
          raise ex || e
        else
          raise ex if ex
        end
      end
    end
  end
end
