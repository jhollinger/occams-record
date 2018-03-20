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

      def eager_load_one(name, mapping, sql, binds = {}, use: nil)
        @eager_loaders << EagerLoaders::AdHocOne.new(name, mapping, sql, binds, use: use)
        self
      end

      def eager_load_many(name, mapping, sql, binds = {}, use: nil)
        @eager_loaders << EagerLoaders::AdHocMany.new(name, mapping, sql, binds, use: use)
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
          EagerLoaders::Habtm
        else
          raise "Unsupported association type `#{macro}`"
        end
      end
    end
  end
end
