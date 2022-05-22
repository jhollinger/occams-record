require 'securerandom'

module OccamsRecord
#
# An interface to database cursors. Supported databases:
#   * PostgreSQL
#
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

    #
    # Initializes a new Cursor. NOTE all operations must be performed within a block passed to #open.
    #
    # While you CAN manually initialize a cursor, it's more common to get one via OccamsRecord::Query#cursor
    # or OccamsRecord::RawQuery#cursor.
    #
    # @param conn [ActiveRecord::Connection]
    # @param sql [String] The query to run
    # @param name [String] Specify a name for the cursor (defaults to a random name)
    # @param scroll [Boolean] true = SCROLL, false = NO SCROLL, nil = default behavior of DB
    # @param hold [Boolean] true = WITH HOLD, false = WITHOUT HOLD, nil = default behavior of DB
    # @param use [Array<Module>] optional Module to include in the result class (single or array)
    # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
    # @param eager_loaders [OccamsRecord::EagerLoaders::Context]
    #
    def initialize(conn, sql, name: nil, scroll: nil, hold: nil, use: nil, query_logger: nil, eager_loaders: nil)
      @conn, @sql = conn, sql
      @scroll = SCROLL.fetch(scroll)
      @hold = HOLD.fetch(hold)
      @use, @query_logger, @eager_loaders = use, query_logger, eager_loaders
      @name = name || "occams_cursor_#{SecureRandom.hex 4}"
      @quoted_name = conn.quote_table_name(@name)
    end

    #
    # Declares and opens the cursor, runs the given block (yielding self), and closes the cursor.
    #
    #   cursor.open do |c|
    #     c.fetch :forward, 100
    #   end
    #
    # @param use_transaction [Boolean] When true, ensures it's wrapped in a transaction
    # @yield [self]
    # @return the value returned by the block
    #
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

    #
    # Loads records in batches of N and yields each record to a block (if given). If no block is given,
    # returns an Enumerator.
    #
    #   cursor.open do |c|
    #     c.each do |record|
    #       ...
    #     end
    #   end
    #
    # @param batch_size [Integer] fetch this many rows at once
    #
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

    #
    # Loads records in batches of N and yields each batch to a block (if given). If no block is given,
    # returns an Enumerator.
    #
    #   cursor.open do |c|
    #     c.each_batch do |batch|
    #       ...
    #     end
    #   end
    #
    # @param batch_size [Integer] fetch this many rows at once
    #
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

    #
    # Fetch records in the given direction. Database support varies. Consult your database's documentation for supported operations.
    #
    #   cursor.open do |c|
    #     c.fetch :forward, 100
    #     ...
    #   end
    #
    # @param direction [Symbol] :next, :prior, :first, :last, :absolute, :relative, :forward or :backward
    # @param num [Integer] number of rows to fetch (optional for some directions)
    # @return [OccamsRecord::Results::Row]
    #
    def fetch(direction, num = nil)
      query "FETCH %{dir} %{num} FROM %{name}".freeze % {
        dir: DIRECTIONS.fetch(direction),
        num: num&.to_i,
        name: @quoted_name,
      }
    end

    #
    # Move the cursor the given direction. Database support varies. Consult your database's documentation for supported operations.
    #
    #   cursor.open do |c|
    #     ...
    #     c.move :backward, 100
    #     ...
    #   end
    #
    # @param direction [Symbol] :next, :prior, :first, :last, :absolute, :relative, :forward or :backward
    # @param num [Integer] number of rows to move (optional for some directions)
    #
    def move(direction, num = nil)
      query "MOVE %{dir} %{num} FROM %{name}".freeze % {
        dir: DIRECTIONS.fetch(direction),
        num: num&.to_i,
        name: @quoted_name,
      }
    end

    #
    # Run an arbitrary query on the cursor. Use 'binds' to escape inputs.
    #
    #   cursor.open do |c|
    #     c.query("FETCH FORWARD %{num} FOR #{c.quoted_name}", {num: 100})
    #     ...
    #   end
    #
    def query(sql, binds = {})
      ::OccamsRecord::RawQuery.new(sql, binds, use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders, connection: conn).run
    end

    #
    # Run an arbitrary command on the cursor. Use 'binds' to escape inputs.
    #
    #   cursor.open do |c|
    #     c.execute("MOVE FORWARD %{num} FOR #{c.quoted_name}", {num: 100})
    #     ...
    #   end
    #
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
