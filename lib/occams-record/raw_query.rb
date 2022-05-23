module OccamsRecord
  #
  # Starts building a OccamsRecord::RawQuery. Pass it a raw SQL statement, optionally followed by
  # a Hash of binds. While this doesn't offer an additional performance boost, it's a nice way to
  # write safe, complicated SQL by hand while also supporting eager loading.
  #
  #   results = OccamsRecord.sql("
  #     SELECT * FROM widgets
  #     WHERE category_id = %{cat_id}
  #   ", {
  #     cat_id: 5
  #   }).run
  #
  # If you want to do eager loading, you must first the define a model to pull the associations from (unless
  # you're using the raw SQL eager loaders `eager_load_one` or `eager_load_many`).
  #
  #   results = OccamsRecord
  #     .sql("
  #       SELECT * FROM widgets
  #       WHERE category_id IN (%{cat_ids})
  #     ", {
  #       cat_ids: [5, 10]
  #     })
  #     .model(Widget)
  #     .eager_load(:category)
  #     .run
  #
  # NOTE To use find_each/find_in_batches, your SQL string must include 'LIMIT %{batch_limit} OFFSET %{batch_offset}',
  # and an ORDER BY is strongly recomended. OccamsRecord will provide the bind values for you.
  #
  # NOTE There is variation of the types of values returned (e.g. a Date object vs a date string) depending on the database
  # and ActiveRecord version being used:
  #
  # Postgres always returns native Ruby types.
  #
  # SQLite will return native types for the following: integers, floats, string/text.
  # For booleans it will return 0|1 for AR 6+, and "t|f" for AR 5-.
  # Dates and times will be ISO8601 formatted strings.
  # It is possible to coerce the SQLite adapter into returning native types for everything IF they're columns of a table
  # that you have an AR model for. e.g. if you're selecting from the widgets, table: `OccamsRecord.sql("...").model(Widget)...`.
  #
  # MySQL ?
  #
  # @param sql [String] The SELECT statement to run. Binds should use Ruby's named string substitution.
  # @param binds [Hash] Bind values (Symbol keys)
  # @param use [Array<Module>] optional Module to include in the result class (single or array)
  # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
  # @return [OccamsRecord::RawQuery]
  #
  def self.sql(sql, binds, use: nil, query_logger: nil)
    RawQuery.new(sql, binds, use: use, query_logger: nil)
  end

  #
  # Represents a raw SQL query to be run and eager associations to be loaded. Use OccamsRecord.sql to create your queries
  # instead of instantiating objects directly.
  #
  class RawQuery
    # @return [String]
    attr_reader :sql
    # @return [Hash]
    attr_reader :binds

    include OccamsRecord::Batches::Cursor::QueryHelpers
    include EagerLoaders::Builder
    include Enumerable
    include Measureable

    #
    # Initialize a new query.
    #
    # @param sql [String] The SELECT statement to run. Binds should use Ruby's named string substitution.
    # @param binds [Hash] Bind values (Symbol keys)
    # @param use [Array<Module>] optional Module to include in the result class (single or array)
    # @param eager_loaders [OccamsRecord::EagerLoaders::Context]
    # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
    # @param measurements [Array]
    # @param connection
    #
    def initialize(sql, binds, use: nil, eager_loaders: nil, query_logger: nil, measurements: nil, connection: nil)
      @sql = sql
      @binds = binds
      @use = use
      @eager_loaders = eager_loaders || EagerLoaders::Context.new
      @query_logger, @measurements = query_logger, measurements
      @conn = connection
    end

    #
    # Specify the model to be used to load eager associations. Normally this would be the main table you're
    # SELECTing from.
    #
    # NOTE Some database adapters, notably SQLite's, require that the model *always* be specified, even if you
    # aren't doing eager loading.
    #
    # @param klass [ActiveRecord::Base]
    # @return [OccamsRecord::RawQuery] self
    #
    def model(klass)
      @eager_loaders.model = klass
      self
    end

    #
    # Run the query and return the results.
    #
    # @return [Array<OccamsRecord::Results::Row>]
    #
    def run
      _escaped_sql = escaped_sql
      @query_logger << _escaped_sql if @query_logger
      result = if measure?
                 record_start_time!
                 measure!(table_name, _escaped_sql) {
                   conn.exec_query _escaped_sql
                 }
               else
                 conn.exec_query _escaped_sql
               end
      row_class = OccamsRecord::Results.klass(result.columns, result.column_types, @eager_loaders.names, model: @eager_loaders.model, modules: @use)
      rows = result.rows.map { |row| row_class.new row }
      @eager_loaders.run!(rows, query_logger: @query_logger, measurements: @measurements)
      yield_measurements!
      rows
    end

    alias_method :to_a, :run

    #
    # If you pass a block, each result row will be yielded to it. If you don't,
    # an Enumerable will be returned.
    #
    # @yield [OccansR::Results::Row]
    # @return [Enumerable]
    #
    def each
      if block_given?
        to_a.each { |row| yield row }
      else
        to_a.each
      end
    end

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
        find_in_batches(batch_size: batch_size, use_transaction: use_transaction).each { |batch|
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
      enum = Batches::OffsetLimit::RawQuery
        .new(conn, @sql, @binds, use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders)
        .enum(batch_size: batch_size, use_transaction: use_transaction)
      if block_given?
        enum.each { |batch| yield batch }
      else
        enum
      end
    end

    #
    # Returns a cursor you can open and perform operations on. A lower-level alternative to 
    # find_each_with_cursor and find_in_batches_with_cursor.
    #
    # NOTE Postgres only. See the docs for OccamsRecord::Cursor for more details.
    #
    # @param name [String] Specify a name for the cursor (defaults to a random name)
    # @param scroll [Boolean] true = SCROLL, false = NO SCROLL, nil = default behavior of DB
    # @param hold [Boolean] true = WITH HOLD, false = WITHOUT HOLD, nil = default behavior of DB
    # @return [OccamsRecord::Cursor]
    #
    def cursor(name: nil, scroll: nil, hold: nil)
      Cursor.new(conn, @sql,
        name: name, scroll: scroll, hold: hold,
        use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders,
      )
    end

    private

    # Returns the SQL as a String with all variables escaped
    def escaped_sql
      return sql if binds.empty?
      sql % binds.reduce({}) { |a, (col, val)|
        a[col.to_sym] = if val.is_a? Array
                          val.map { |x| conn.quote x }.join(', ')
                        else
                          conn.quote val
                        end
        a
      }
    end

    def table_name
      @sql.match(/\s+FROM\s+"?(\w+)"?/i)&.captures&.first
    end

    def conn
      @conn ||= @eager_loaders.model&.connection || ActiveRecord::Base.connection
    end
  end
end
