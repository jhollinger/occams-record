module MicroRecord
  #
  # Starts building a MicroRecord::Query. Pass it a scope from any of ActiveRecord's query builder
  # methods or associations. If you want to eager loaded associations, do NOT us ActiveRecord for it.
  # Instead, use MicroRecord::Query#eager_load. Finally, call `run` to run the query and get back an
  # array of objects.
  #
  #  results = MicroRecord.
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
  # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
  # @return [MicroRecord::Query]
  #
  def self.query(query, query_logger = nil)
    Query.new(query, query_logger)
  end

  class Query
    # @return [ActiveRecord::Base]
    attr_reader :model
    # @return [String] SQL string for the main query
    attr_reader :sql
    # @return [ActiveRecord::Connection]
    attr_reader :conn
    # @return [Array<MicroRecord::EagerLoaders::Base>]
    attr_reader :eager_loaders

    #
    # Initialize a new query.
    #
    # @param query [ActiveRecord::Relation]
    # @param query_logger [Array] (optional) an array into which all queries will be inserted for logging/debug purposes
    # @param eval_block [Proc] block that will be eval'd on this instance. Can be used for eager loading. (optional)
    #
    def initialize(query, query_logger = nil, &eval_block)
      @model = query.klass
      @sql = query.to_sql
      @eager_loaders = []
      @conn = model.connection
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
    # @param eval_block [Proc] a block where you may perform eager loading on *this* association (optional)
    #
    def eager_load(assoc, scope = nil, &eval_block)
      ref = model.reflections[assoc.to_s]
      raise "MicroRecord: No assocation `:#{assoc}` on `#{model.name}`" if ref.nil?
      @eager_loaders << EagerLoaders.fetch!(ref.macro).new(ref, scope, &eval_block)
      self
    end

    #
    # Run the query and return the results.
    #
    # @return [Array<MicroRecord::ResultRow>]
    #
    def run
      @query_logger << sql if @query_logger
      result = conn.exec_query sql
      row_class = MicroRecord.build_result_row_class(model, result.columns, eager_loaders.map(&:name))
      rows = result.rows.map { |row| row_class.new row }

      eager_loaders.each { |loader|
        assoc_rows = Query.new(loader.query(rows), @query_logger, &loader.eval_block).run
        loader.merge! assoc_rows, rows
      }

      rows
    end
  end
end
