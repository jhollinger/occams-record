require 'securerandom'

module OccamsRecord
  module Batches
    class Cursor
      DECLARE = "DECLARE %{name} %{scroll} CURSOR %{hold} FOR %{query}".freeze
      CLOSE = "CLOSE %{name}".freeze
      SCROLL = {
        true => "SCROLL",
        false => "NO SCROLL",
        nil => "",
      }.freeze
      HOLD = {
        true => "WITH HOLD",
        false => "WITHOUT HOLD",
        nil => "",
      }.freeze
      DIRECTIONS = {
        next: "NEXT",
        prior: "PRIOR",
        first: "FIRST",
        last: "LAST",
        absolute: "ABSOLUTE",
        relative: "RELATIVE",
        forward: "FORWARD",
        backward: "BACKWARD",
      }.freeze

      attr_reader :conn, :name, :quoted_name

      def initialize(conn, sql, name: nil, scroll: nil, hold: nil, use: nil, query_logger: nil, eager_loaders: nil)
        @conn, @sql = conn, sql
        @scroll = SCROLL.fetch(scroll)
        @hold = HOLD.fetch(hold)
        @use, @query_logger, @eager_loaders = use, query_logger, eager_loaders
        @name = name || "occams_cursor_#{SecureRandom.hex 4}"
        @quoted_name = conn.quote_table_name(@name)
      end

      def open(use_transaction: true)
        raise ArgumentError, "A block is required" unless block_given?
        if use_transaction and conn.open_transactions == 0
          conn.transaction {
            perform { yield self }
          }
        else
          perform { yield self }
        end
      end

      def each(batch_size: 1000)
        enum = Enumerator.new { |y|
          each_batch(batch_size: batch_size).each { |batch|
            batch.each { |record| y.yield record }
          }
        }
        if block_given?
          enum.each { |record| yield record }
        else
          enum
        end
      end

      def each_batch(batch_size: 1000)
        enum = Enumerator.new { |y|
          out_of_records = false
          until out_of_records
            results = fetch :forward, batch_size
            y.yield results if results.any?
            out_of_records = results.size < batch_size
          end
        }
        if block_given?
          enum.each { |batch| yield batch }
        else
          enum
        end
      end

      def fetch(direction, num = nil)
        query "FETCH %{dir} %{num} FROM %{name}".freeze % {
          dir: DIRECTIONS.fetch(direction),
          num: num&.to_i,
          name: @quoted_name,
        }
      end

      def move(direction, num = nil)
        query "MOVE %{dir} %{num} FROM %{name}".freeze % {
          dir: DIRECTIONS.fetch(direction),
          num: num&.to_i,
          name: @quoted_name,
        }
      end

      def query(sql, binds = {})
        ::OccamsRecord::RawQuery.new(sql, binds, use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders, connection: conn).run
      end

      def execute(sql, binds = {})
        conn.execute(sql % binds.reduce({}) { |acc, (key, val)|
          acc[key] = conn.quote(val)
          acc
        })
      end

      private

      def perform
        ex = nil
        conn.execute DECLARE % {
          name: @quoted_name,
          scroll: @scroll,
          hold: @hold,
          query: @sql,
        }
        yield
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
