module MicroRecord
  #
  # Starts building a MicroRecord::Query. Pass it a scope from any of ActiveRecord's query builder
  # methods or associations. If you want to eager loaded associations, do NOT us ActiveRecord for it.
  # Instead, use MicroRecord::Query#eager_load. Finally, call `run` to run the query and get back an
  # array of OpenStructs.
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
  # @return [MicroRecord::Query]
  #
  def self.query(query)
    Query.new(query)
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
    # @param eval_block [Proc] block that will be eval'd on this instance. Can be used for eager loading. (optional)
    #
    def initialize(query, &eval_block)
      @model = query.klass
      @sql = query.to_sql
      @eager_loaders = []
      @conn = model.connection
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
    # Run the query and return the structs.
    #
    # @param native_types [Boolean] if true parse the raw results into native Ruby types
    # @return [Array<OpenStruct>]
    #
    def run(native_types: true)
      rows = get_rows(sql, native_types).map { |hash|
        OpenStruct.new hash
      }

      eager_loaders.each { |loader|
        assoc_rows = Query.new(loader.query(rows), &loader.eval_block).
          run(native_types: native_types)
        loader.merge! assoc_rows, rows
      }

      rows
    end

    private

    #
    # Run the sql and return the rows as Hashes.
    #
    # @param sql [String]
    # @param native_types [Boolean] if true parse the raw results into native Ruby types
    # @return [Array<Hash>]
    #
    def get_rows(sql, native_types = false)
      result = conn.exec_query sql
      if native_types
        # While result.column_types works for some db drivers, others don't provide any type info (i.e. sqlite)
        column_types = model.columns_hash.values_at(*result.columns).map { |c| c ? c.type : nil }
        converter = TypeConverter.fetch!(conn.adapter_name).new(column_types, result.columns)
        result.rows.map { |row| converter.to_hash row }
      else
        result.to_hash
      end
    end
  end
end
