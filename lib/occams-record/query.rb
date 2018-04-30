require 'occams-record/batches'

module OccamsRecord
  #
  # Starts building a OccamsRecord::Query. Pass it a scope from any of ActiveRecord's query builder
  # methods or associations. If you want to eager loaded associations, do NOT us ActiveRecord for it.
  # Instead, use OccamsRecord::Query#eager_load. Finally, call `run` to run the query and get back an
  # array of objects.
  #
  #  results = OccamsRecord.
  #    query(Widget.order("name")).
  #    eager_load(:category).
  #    eager_load(:order_items, ->(q) { q.select("widget_id, order_id") }) {
  #      eager_load(:orders) {
  #        eager_load(:customer, ->(q) { q.select("name") })
  #      }
  #    }.
  #    run
  #
  # @param scope [ActiveRecord::Relation]
  # @param use [Module] optional Module to include in the result class
  # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
  # @return [OccamsRecord::Query]
  #
  def self.query(scope, use: nil, query_logger: nil)
    Query.new(scope, use: use, query_logger: query_logger)
  end

  #
  # Represents a query to be run and eager associations to be loaded. Use OccamsRecord.query to create your queries
  # instead of instantiating objects directly.
  #
  class Query
    # @return [ActiveRecord::Base]
    attr_reader :model
    # @return [ActiveRecord::Relation] scope for building the main SQL query
    attr_reader :scope

    include Batches
    include EagerLoaders::Builder
    include Enumerable

    #
    # Initialize a new query.
    #
    # @param scope [ActiveRecord::Relation]
    # @param use [Array<Module>] optional Module to include in the result class (single or array)
    # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
    # @param eager_loaders [OccamsRecord::EagerLoaders::Base]
    # @yield will be eval'd on this instance. Can be used for eager loading. (optional)
    #
    def initialize(scope, use: nil, query_logger: nil, eager_loaders: [], &eval_block)
      @model = scope.klass
      @scope = scope
      @eager_loaders = eager_loaders
      @use = use
      @query_logger = query_logger
      instance_eval(&eval_block) if eval_block
    end

    #
    # Run the query and return the results.
    #
    # You may optionally pass a block to modify the query just before it's run (the change will NOT persist).
    # This is very useful for running paginated queries.
    #
    #   occams = OccamsRecord.query(Widget.all)
    #
    #   # returns first 100 rows
    #   occams.run { |q| q.offset(0).limit(100) }
    #
    #   # returns second 100 rows
    #   occams.run { |q| q.offset(100).limit(100) }
    #
    #   # returns ALL rows
    #   occams.run
    #
    # @return [Array<OccamsRecord::Results::Row>]
    # @yield [ActiveRecord::Relation] You may use this to return and run a modified relation
    #
    def run
      sql = block_given? ? yield(scope).to_sql : scope.to_sql
      @query_logger << sql if @query_logger
      result = model.connection.exec_query sql
      row_class = OccamsRecord::Results.klass(result.columns, result.column_types, @eager_loaders.map(&:name), model: model, modules: @use)
      rows = result.rows.map { |row| row_class.new row }
      eager_load! rows
      rows
    end

    alias_method :to_a, :run

    #
    # Returns the number of rows that will be returned if the query is run.
    #
    # @return [Integer]
    #
    def count
      scope.count
    end

    #
    # Run the query with LIMIT 1 and return the first result (which could be nil).
    #
    # @return [OccamsRecord::Results::Row]
    #
    def first
      run { |q| q.limit 1 }.first
    end

    #
    # Run the query with LIMIT 1 and return the first result. If nothing is found
    # an OccamsRecord::NotFound exception will be raised.
    #
    # @return [OccamsRecord::Results::Row]
    #
    def first!
      first || raise(OccamsRecord::NotFound.new(model.name, scope.where_values_hash))
    end

    #
    # If you pass a block, each result row will be yielded to it. If you don't,
    # an Enumerable will be returned.
    #
    # @yield [OccamsRecord::Results::Row]
    # @return Enumerable
    #
    def each
      if block_given?
        to_a.each { |row| yield row }
      else
        to_a.each
      end
    end
  end
end
