module OccamsRecord
  module EagerLoaders
    #
    # Methods for adding eager loading to a query.
    #
    # Users MUST have an OccamsRecord::EagerLoaders::Context at @eager_loaders.
    #
    module Builder
      #
      # Specify an association to be eager-loaded. For maximum memory savings, only SELECT the
      # colums you actually need.
      #
      # @param assoc [Symbol] name of association
      # @param scope [Proc] a scope to apply to the query (optional). It will be passed an
      # ActiveRecord::Relation on which you may call all the normal query hethods (select, where, etc) as well as any scopes you've defined on the model.
      # @param select [String] a custom SELECT statement, minus the SELECT (optional)
      # @param use [Array<Module>] optional Module to include in the result class (single or array)
      # @param as [Symbol] Load the association usign a different attribute name
      # @param from [Symbol] Opposite of `as`. `assoc` is the custom name and `from` is the name of association on the ActiveRecord model.
      # @param optimizer [Symbol] Only used for `through` associations. Options are :none (load all intermediate records) | :select (load all intermediate records but only SELECT the necessary columns)
      # @yield a block where you may perform eager loading on *this* association (optional)
      # @return self
      #
      def eager_load(assoc, scope = nil, select: nil, use: nil, as: nil, from: nil, optimizer: :select, &builder)
        @eager_loaders.add(assoc, scope, select: select, use: use, as: as, from: from, optimizer: optimizer, &builder)
        self
      end

      #
      # Same as eager_load, except it returns the new eager loader object instead of self. You can use the
      # new object to call "nest" again, programtically building up nested eager loads instead of passing
      # nested blocks.
      #
      # @param assoc [Symbol] name of association
      # @param scope [Proc] a scope to apply to the query (optional). It will be passed an
      # ActiveRecord::Relation on which you may call all the normal query hethods (select, where, etc) as well as any scopes you've defined on the model.
      # @param select [String] a custom SELECT statement, minus the SELECT (optional)
      # @param use [Array<Module>] optional Module to include in the result class (single or array)
      # @param as [Symbol] Load the association usign a different attribute name
      # @param from [Symbol] Opposite of `as`. `assoc` is the custom name and `from` is the name of association on the ActiveRecord model.
      # @param optimizer [Symbol] Only used for `through` associations. Options are :none (load all intermediate records) | :select (load all intermediate records but only SELECT the necessary columns)
      # @return [OccamsRecord::EagerLoaders::Base]
      #
      def nest(assoc, scope = nil, select: nil, use: nil, as: nil, from: nil, optimizer: :select)
        raise ArgumentError, "OccamsRecord::EagerLoaders::Builder#nest does not accept a block!" if block_given?
        @eager_loaders.add(assoc, scope, select: select, use: use, as: as, from: from, optimizer: optimizer) ||
          raise("OccamsRecord::EagerLoaders::Builder#nest may not be called under a polymorphic association")
      end

      #
      # Specify some arbitrary SQL to be loaded into some arbitrary attribute ("name"). The attribute will
      # hold either one record or none.
      #
      # In the example below, :category is NOT an association on Widget. Though if it where it would be a belongs_to. The
      # mapping argument says "The category_id in the parent (Widget) maps to the id column in the child records (Category).
      #
      # The %{category_ids} bind param will be provided for you, and in this case will be all the category_id values from the Widget query.
      #
      #   res = OccamsRecord
      #     .query(Widget.order("name"))
      #     .eager_load_one(:category, {:category_id => :id}, "
      #       SELECT * FROM categories WHERE id IN (%{category_ids}) AND name != %{bad_name}
      #     ", binds: {
      #       bad_name: "Bad Category"
      #     })
      #     .run
      #
      # @param name [Symbol] name of attribute to load records into
      # @param mapping [Hash] a Hash that defines the key mapping of the parent (widgets.category_id) to the child (categories.id).
      # @param sql [String] the SQL to query the associated records. Include a bind params called '%{ids}' for the foreign/parent ids.
      # @param binds [Hash] any additional binds for your query.
      # @param model [ActiveRecord::Base] optional - ActiveRecord model that represents what you're loading. required when using Sqlite.
      # @param use [Array<Module>] optional - Ruby modules to include in the result objects (single or array)
      # @yield eager load associations nested under this one
      # @return self
      #
      def eager_load_one(name, mapping, sql, binds: {}, model: nil, use: nil, &builder)
        @eager_loaders << EagerLoaders::AdHocOne.new(name, mapping, sql, binds: binds, model: model, use: use, &builder)
        self
      end

      #
      # Specify some arbitrary SQL to be loaded into some arbitrary attribute ("name"). The attribute will
      # hold an array of 0 or more associated records.
      #
      # In the example below, :parts is NOT an association on Widget. Though if it where it would be a has_many. The
      # mapping argument says "The id column in the parent (Widget) maps to the widget_id column in the children.
      #
      # The %{ids} bind param will be provided for you, and in this case will be all the id values from the Widget
      # query.
      #
      #   res = OccamsRecord
      #     .query(Widget.order("name"))
      #     .eager_load_many(:parts, {:id => :widget_id}, "
      #       SELECT * FROM parts WHERE widget_id IN (%{ids}) AND sku NOT IN (%{bad_skus})
      #     ", binds: {
      #       bad_skus: ["G90023ASDf0"]
      #     })
      #     .run
      #
      # @param name [Symbol] name of attribute to load records into
      # @param mapping [Hash] a Hash that defines the key mapping of the parent (widgets.id) to the children (parts.widget_id).
      # @param sql [String] the SQL to query the associated records. Include a bind params called '%{ids}' for the foreign/parent ids.
      # @param use [Array<Module>] optional - Ruby modules to include in the result objects (single or array)
      # @param binds [Hash] any additional binds for your query.
      # @param model [ActiveRecord::Base] optional - ActiveRecord model that represents what you're loading. required when using Sqlite.
      # @yield eager load associations nested under this one
      # @return self
      #
      def eager_load_many(name, mapping, sql, binds: {}, model: nil, use: nil, &builder)
        @eager_loaders << EagerLoaders::AdHocMany.new(name, mapping, sql, binds: binds, model: model, use: use, &builder)
        self
      end
    end
  end
end
