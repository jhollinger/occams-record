module OccamsRecord
  #
  # Contains eager loaders for various kinds of associations.
  #
  module EagerLoaders
    autoload :Base, 'occams-record/eager_loaders/base'
    autoload :BelongsTo, 'occams-record/eager_loaders/belongs_to'
    autoload :PolymorphicBelongsTo, 'occams-record/eager_loaders/polymorphic_belongs_to'
    autoload :HasOne, 'occams-record/eager_loaders/has_one'
    autoload :HasMany, 'occams-record/eager_loaders/has_many'
    autoload :Habtm, 'occams-record/eager_loaders/habtm'

    autoload :AdHocBase, 'occams-record/eager_loaders/ad_hoc_base'
    autoload :AdHocOne, 'occams-record/eager_loaders/ad_hoc_one'
    autoload :AdHocMany, 'occams-record/eager_loaders/ad_hoc_many'

    # Methods for adding eager loading to a query.
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
      # @yield a block where you may perform eager loading on *this* association (optional)
      # @return [OccamsRecord::Query] returns self
      #
      def eager_load(assoc, scope = nil, select: nil, use: nil, as: nil, &eval_block)
        ref = @model ? @model.reflections[assoc.to_s] : nil
        ref ||= @model.subclasses.map(&:reflections).detect { |x| x.has_key? assoc.to_s }&.[](assoc.to_s) if @model
        raise "OccamsRecord: No assocation `:#{assoc}` on `#{@model&.name || '<model missing>'}` or subclasses" if ref.nil?
        scope ||= ->(q) { q.select select } if select
        @eager_loaders << eager_loader_for_association(ref).new(ref, scope, use: use, as: as, &eval_block)
        self
      end

      #
      # Specify some arbitrary SQL to be loaded into some arbitrary attribute ("name"). The attribute will
      # hold either one record or none.
      #
      # In the example below, :category is NOT an association on Widget. Though if it where it would be a belongs_to. The
      # mapping argument says "The id column in this table (categories) maps to the category_id column in the other table (widgets)".
      # The %{ids} bind param will be provided for you, and in this case will be all the category_id values from the main
      # query.
      #
      #   res = OccamsRecord.
      #     query(Widget.order("name")).
      #     eager_load_one(:category, {:id => :category_id}, %(
      #       SELECT * FROM categories WHERE id IN (%{ids}) AND name != %{bad_name}
      #     ), binds: {
      #       bad_name: "Bad Category"
      #     }).
      #     run
      #
      # @param name [Symbol] name of attribute to load records into
      # @param mapping [Hash] a one element Hash with the key being the local/child id and the value being the foreign/parent id
      # @param sql [String] the SQL to query the associated records. Include a bind params called '%{ids}' for the foreign/parent ids.
      # @param binds [Hash] any additional binds for your query.
      # @param model [ActiveRecord::Base] optional - ActiveRecord model that represents what you're loading. required when using Sqlite.
      # @param use [Array<Module>] optional - Ruby modules to include in the result objects (single or array)
      #
      def eager_load_one(*args, &eval_block)
        @eager_loaders << EagerLoaders::AdHocOne.new(*args, &eval_block)
        self
      end

      #
      # Specify some arbitrary SQL to be loaded into some arbitrary attribute ("name"). The attribute will
      # hold an array of 0 or more associated records.
      #
      # In the example below, :parts is NOT an association on Widget. Though if it where it would be a has_many. The
      # mapping argument says "The widget_id column in this table (parts) maps to the id column in the other table (widgets)".
      # The %{ids} bind param will be provided for you, and in this case will be all the id values from the main
      # query.
      #
      #   res = OccamsRecord.
      #     query(Widget.order("name")).
      #     eager_load_many(:parts, {:widget_id => :id}, %(
      #       SELECT * FROM parts WHERE widget_id IN (%{ids}) AND sku NOT IN (%{bad_skus})
      #     ), binds: {
      #       bad_skus: ["G90023ASDf0"]
      #     }).
      #     run
      #
      # @param name [Symbol] name of attribute to load records into
      # @param mapping [Hash] a one element Hash with the key being the local/child id and the value being the foreign/parent id
      # @param sql [String] the SQL to query the associated records. Include a bind params called '%{ids}' for the foreign/parent ids.
      # @param use [Array<Module>] optional - Ruby modules to include in the result objects (single or array)
      # @param binds [Hash] any additional binds for your query.
      # @param model [ActiveRecord::Base] optional - ActiveRecord model that represents what you're loading. required when using Sqlite.
      #
      def eager_load_many(*args, &eval_block)
        @eager_loaders << EagerLoaders::AdHocMany.new(*args, &eval_block)
        self
      end

      private

      # Run all defined eager loaders into the given result rows
      def eager_load!(rows)
        @eager_loaders.each { |loader|
          loader.run(rows, query_logger: @query_logger)
        }
      end

      # Fetch the appropriate eager loader for the given association type.
      def eager_loader_for_association(ref)
        case ref.macro
        when :belongs_to
          ref.options[:polymorphic] ? PolymorphicBelongsTo : BelongsTo
        when :has_one
          HasOne
        when :has_many
          HasMany
        when :has_and_belongs_to_many
          Habtm
        else
          raise "Unsupported association type `#{macro}`"
        end
      end
    end
  end
end
