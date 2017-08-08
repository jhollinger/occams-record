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
  # @param native_types [Boolean] convert string values to native types (default true)
  # @param connection [ActiveRecord::Connection] defaults to ActiveRecord::Base.connection
  # @return [MicroRecord::Query]
  #
  def self.query(query, native_types: true, connection: nil)
    Query.new(query, connection)
  end

  class Query
    # @return [ActiveRecord::Base]
    attr_reader :model
    # @return [String] SQL string for the main query
    attr_reader :sql
    # @return [Boolean] convert string values to native types
    attr_reader :native_types
    # @return [ActiveRecord::Connection]
    attr_reader :conn
    # @return [Array<MicroRecord::EagerLoader>]
    attr_reader :eager_loaders

    #
    # Initialize a new query.
    #
    # @param query [ActiveRecord::Relation]
  # @param native_types [Boolean] convert string values to native types (default true)
    # @param connection [ActiveRecord::Connection] defaults to ActiveRecord::Base.connection
    #
    def initialize(query, native_types: true, connection: nil)
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
      @eager_loaders << case ref.macro
                        when :has_many, :belongs_to, :has_one
                          EagerLoader.new(ref, scope)
                        when :has_and_belongs_to_many
                          raise 'TODO'
                          HabtmEagerLoader.new(ref, scope)
                        else
                          raise "Unsupported association type `#{ref.macro}`"
                        end
      self
    end

    #
    # Run the query and return the Hashes.
    #
    def run
      # Build a Hash of empty associations to merge into each row.
      empty_associations = eager_loaders.reduce({}) { |a, loader|
        a[loader.name] = loader.many ? [] : nil
        a
      }

      # Query rows from the main query and put them in a Hash keyed by ID.
      rows_by_id = get_rows(sql).reduce({}) { |a, row|
        id = row.fetch model.primary_key.to_s
        row.merge! empty_associations
        a[id] = row
        a
      }

      # Query belongs_to & has_one associations and stick them into the appropriate records
      belongs_tos = get_associations_by_id eager_loaders.select(&:single?), rows_by_id.keys
      rows_by_id.each do |_, row|
        belongs_tos.each do |loader, assoc_rows_by_id|
          if (fkey = row[loader.fkey])
            row[loader.name] = assoc_rows_by_id[fkey]
          end
        end
      end

      # Query has_many & habtm associations and stick them into the appropriate records
      eager_loaders.select(&:multi).each do |loader|
        assoc_rows = get_rows loader.sql rows_by_id.keys
        assoc_rows.each do |assoc_row|
          fkey = loader.fetch_fkey! assoc_row
          if (row = rows_by_id[fkey])
            row[loader.name] << assoc_row
          end
        end
      end

      rows_by_id.values
    end

    private

    #
    # Run the sql and return the rows as Hashes.
    #
    # @param sql [String]
    #
    def get_rows(sql)
      result = conn.exec_query sql
      if native_types
        converter = TypeConverter.new(result.columns, result.column_types.map(&:type))
        result.rows.map { |row| converter.to_hash row }
      else
        result.to_hash
      end
    end

    def get_associations_by_id(eager_loaders, primary_keys)
      eager_loaders.reduce({}) { |a, loader|
        rows_by_id = get_rows(loader.sql primary_keys).reduce({}) { |rows, row|
          id = row[loader.pkey]
          rows[id] = row
          rows
        }
        a[loader] = rows_by_id
      }
    end
  end
end
