module MicroRecord
  #
  # Starts building a MicroRecord::Query. Pass it a scope from any of ActiveRecord's query builder
  # methods or associations. If you want to eager loaded associations, do NOT us ActiveRecord for it.
  # Instead, use MicroRecord::Query#eager_load. Finally, call `run` to run the query and get back an
  # array of Hashes.
  #
  #   results = MicroRecord.
  #     query(Widget.where(category_id: 42)).
  #     eager_load(:category).
  #     eager_load(:orders) { |q| q.where("date >= ?", 5.days.ago").select("id, date") }.
  #     run
  #
  #   puts results
  #   => [
  #     {"id" => 1, "name" => "Widget 1", "category_id" => 5, "category" => {"id" => 5, "name" => "Foo"}, "orders" => [
  #       {"id" => 1000, "date" => #<Date: 2017-01-01>}, {"id" => 1001, "date" => #<Date: 2017-01-02>}
  #     ]},
  #     {"id" => 2, "name" => "Widget 2", "category_id" => 6, "category" => {"id" => 6, "name" => "Bar"}, "orders" => [
  #       ...
  #     ]},
  #     ...
  #   ]
  #
  # @param query [ActiveRecord::Relation]
  # @param connection [ActiveRecord::Connection] defaults to ActiveRecord::Base.connection
  # @return [MicroRecord::Query]
  #
  def self.query(query, connection: nil)
    Query.new(query, connection)
  end

  class Query
    # @return [ActiveRecord::Base]
    attr_reader :model
    # @return [String] SQL string for the main query
    attr_reader :sql
    # @return [ActiveRecord::Connection]
    attr_reader :conn
    # @return [Array<MicroRecord::EagerLoader>]
    attr_reader :eager_loaders

    #
    # Initialize a new query.
    #
    # @param query [ActiveRecord::Relation]
    # @param connection [ActiveRecord::Connection] defaults to ActiveRecord::Base.connection
    #
    def initialize(query, connection: nil)
      @model = query.klass
      @sql = query.to_sql
      @eager_loaders = []
      @conn = connection || ActiveRecord::Base.connection
    end

    #
    # Specify an association to be eager-loaded. You may optionally pass a block that accepts a scope
    # which you may modify to customize the query. For maximum memory savings, always `select` only
    # the colums you actually need.
    #
    # @param assoc [Symbol] name of association
    #
    def eager_load(assoc, &scope)
      ref = model.reflections.fetch assoc.to_s
      base_scope = scope ? scope.(ref.klass.all) : ref.klass.all
      @eager_loaders << EagerLoader.new(ref.name.to_s, ref.foreign_key, base_scope)
      self
    end

    #
    # Run the query and return the Hashes.
    #
    # @param native_types [Boolean] convert string values to native Ruby types (default true)
    # @return [Array<Hash>]
    #
    def run(native_types: true)
      # Build a Hash of empty associations to merge into each row.
      empty_associations = eager_loaders.reduce({}) { |a, loader|
        a[loader.name] = []
        a
      }

      # Query rows from the main query and put them in a Hash keyed by ID.
      rows_by_id = get_rows(sql, native_types).reduce({}) { |a, row|
        id = row.fetch model.primary_key.to_s
        row.merge! empty_associations
        a[id] = row
        a
      }

      # Load all the associations into a Hash keyed by EagerLoader.
      eager_rows = eager_loaders.reduce({}) { |a, loader|
        sql = loader.sql(primary_keys)
        a[loader] = get_rows sql, native_types
        a
      }

      # Loop through each record for each eager loaded assoc and assign them to records.
      # TODO this only works for has_* & belongs_to right now. Add support for HABTM.
      eager_rows.each { |loader, loaded_rows|
        loaded_rows.each { |loaded_row|
          fkey = loaded_row.fetch loader.fkey
          if (row = rows_by_id[fkey])
            row[loader.name] << loaded_row
          end
        }
      }
    end

    private

    #
    # Run the sql and return the rows as Hashes.
    #
    # @param sql [String]
    # @param native_types [Boolean]
    #
    def get_rows(sql, native_types = false)
      result = conn.exec_query sql
      if native_types
        converter = TypeConverter.new(result.columns, result.column_types.map(&:type))
        result.rows.map { |row| converter.to_hash row }
      else
        result.to_hash
      end
    end
  end
end
