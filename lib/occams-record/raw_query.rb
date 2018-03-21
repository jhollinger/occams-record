module OccamsRecord
  #
  # Starts building a OccamsRecord::RawQuery. Pass it a raw SQL statement, optionally followed by
  # a Hash of binds. While this doesn't offer an additional performance boost, it's a nice way to
  # write safe, complicated SQL by hand while also supporting eager loading.
  #
  #   results = OccamsRecord.sql(%(
  #     SELECT * FROM widgets
  #     WHERE category_id = %{cat_id}
  #   ), {
  #     cat_id: 5
  #   }).run
  #
  # If you want to do eager loading, you must first the define a model to pull the associations from (unless
  # you're using the raw SQL eager loaders `eager_load_one` or `eager_load_many`).
  # NOTE If you're using SQLite, you must *always* specify the model.
  #
  #   results = OccamsRecord.
  #     sql(%(
  #       SELECT * FROM widgets
  #       WHERE category_id IN (%{cat_ids})
  #     ), {
  #       cat_ids: [5, 10]
  #     }).
  #     model(Widget).
  #     eager_load(:category).
  #     run
  #
  # NOTE To use find_each/find_in_batches, your SQL string must include 'LIMIT %{batch_limit} OFFSET %{batch_offset}',
  # and an ORDER BY is strongly recomended.
  # OccamsRecord will provide the bind values for you.
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

    #
    # Initialize a new query.
    #
    # @param sql [String] The SELECT statement to run. Binds should use Ruby's named string substitution.
    # @param binds [Hash] Bind values (Symbol keys)
    # @param use [Array<Module>] optional Module to include in the result class (single or array)
    # @param eager_loaders [OccamsRecord::EagerLoaders::Base]
    # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
    #
    def initialize(sql, binds, use: nil, eager_loaders: [], query_logger: nil, &eval_block)
      @sql = sql
      @binds = binds
      @use = use
      @eager_loaders = eager_loaders
      @query_logger = query_logger
      @model = nil
      @conn = @model&.connection || ActiveRecord::Base.connection
      instance_eval(&eval_block) if eval_block
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
      @model = klass
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
      result = @conn.exec_query _escaped_sql
      row_class = OccamsRecord::Results.klass(result.columns, result.column_types, @eager_loaders.map(&:name), model: @model, modules: @use)
      rows = result.rows.map { |row| row_class.new row }
      eager_load! rows
      rows
    end

    alias_method :to_a, :run

    #
    # Run the query and return the first result (which could be nil). IMPORTANT you MUST add LIMIT 1 yourself!
    #
    # @return [OccamsRecord::Results::Row]
    #
    def first
      run[0]
    end

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
      sql % binds.reduce({}) { |a, (col, val)|
        a[col.to_sym] = if val.is_a? Array
                          val.map { |x| @conn.quote x }.join(', ')
                        else
                          @conn.quote val
                        end
        a
      }
    end

    #
    # Returns an Enumerator that yields batches of records, of size "of".
    # The SQL string must include 'LIMIT %{batch_limit} OFFSET %{batch_offset}'.
    # The bind values will be provided by OccamsRecord.
    #
    # @param of [Integer] batch size
    # @return [Enumerator] yields batches
    #
    def batches(of:)
      unless @sql =~ /LIMIT\s+%\{batch_limit\}/i and @sql =~ /OFFSET\s+%\{batch_offset\}/i
        raise ArgumentError, "When using find_each/find_in_batches you must specify 'LIMIT %{batch_limit} OFFSET %{batch_offset}'. SQL statement: #{@sql}"
      end

      Enumerator.new do |y|
        offset = 0
        loop do
          results = RawQuery.new(@sql, @binds.merge({
            batch_limit: of,
            batch_offset: offset,
          }), use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders).model(@model).run

          y.yield results if results.any?
          break if results.size < of
          offset += results.size
        end
      end
    end
  end
end
