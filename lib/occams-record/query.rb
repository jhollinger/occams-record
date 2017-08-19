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
  # @param query [ActiveRecord::Relation]
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
    # @return [ActiveRecord::Connection]
    attr_reader :conn

    include Batches

    #
    # Initialize a new query.
    #
    # @param scope [ActiveRecord::Relation]
    # @param use [Module] optional Module to include in the result class
    # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
    # @param eager_loaders [OccamsRecord::EagerLoaders::Base]
    # @param eval_block [Proc] block that will be eval'd on this instance. Can be used for eager loading. (optional)
    #
    def initialize(scope, use: nil, query_logger: nil, eager_loaders: [], &eval_block)
      @model = scope.klass
      @scope = scope
      @eager_loaders = eager_loaders
      @conn = model.connection
      @use = use
      @query_logger = query_logger
      instance_eval(&eval_block) if eval_block
    end

    #
    # Specify an association to be eager-loaded. You may optionally pass a block that accepts a scope
    # which you may modify to customize the query. For maximum memory savings, always `select` only
    # the colums you actually need.
    #
    # @param assoc [Symbol] name of association
    # @param scope [Proc] a scope to apply to the query (optional)
    # @param use [Module] optional Module to include in the result class
    # @param eval_block [Proc] a block where you may perform eager loading on *this* association (optional)
    # @return [OccamsRecord::Query] returns self
    #
    def eager_load(assoc, scope = nil, use: nil, &eval_block)
      ref = model.reflections[assoc.to_s]
      raise "OccamsRecord: No assocation `:#{assoc}` on `#{model.name}`" if ref.nil?
      @eager_loaders << EagerLoaders.fetch!(ref).new(ref, scope, use, &eval_block)
      self
    end

    #
    # Run the query and return the results.
    #
    # @return [Array<OccamsRecord::ResultRow>]
    #
    def run
      sql = scope.to_sql
      @query_logger << sql if @query_logger
      result = conn.exec_query sql
      row_class = OccamsRecord.build_result_row_class(model, result.columns, @eager_loaders.map(&:name), @use)
      rows = result.rows.map { |row| row_class.new row }

      @eager_loaders.each { |loader|
        loader.query(rows) { |scope|
          assoc_rows = Query.new(scope, use: loader.use, query_logger: @query_logger, &loader.eval_block).run
          loader.merge! assoc_rows, rows
        }
      }

      rows
    end
  end
end
