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

    include Batches
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
    #
    def initialize(sql, binds, use: nil, eager_loaders: nil, query_logger: nil, measurements: nil)
      @sql = sql
      @binds = binds
      @use = use
      @eager_loaders = eager_loaders || EagerLoaders::Context.new
      @query_logger, @measurements = query_logger, measurements
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

    #
    # Returns an Enumerator that yields batches of records, of size "of".
    # The SQL string must include 'LIMIT %{batch_limit} OFFSET %{batch_offset}'.
    # The bind values will be provided by OccamsRecord.
    #
    # @param of [Integer] batch size
    # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
    # @return [Enumerator] yields batches
    #
    def batches(of:, use_transaction: true, append_order_by: nil)
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
        results = RawQuery.new(@sql, @binds.merge({
          batch_limit: of,
          batch_offset: offset,
        }), use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders).run

        y.yield results if results.any?
        break if results.size < of
        offset += results.size
      end
    end

    def conn
      @conn ||= @eager_loaders.model&.connection || ActiveRecord::Base.connection
    end
  end
end
