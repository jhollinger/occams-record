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

    # Methods for adding eager loading to a query.
    module Builder
      #
      # Specify an association to be eager-loaded. You may optionally pass a block that accepts a scope
      # which you may modify to customize the query. For maximum memory savings, always `select` only
      # the colums you actually need.
      #
      # @param assoc [Symbol] name of association
      # @param scope [Proc] a scope to apply to the query (optional)
      # @param select [String] a custom SELECT statement, minus the SELECT (optional)
      # @param use [Array<Module>] optional Module to include in the result class (single or array)
      # @param eval_block [Proc] a block where you may perform eager loading on *this* association (optional)
      # @return [OccamsRecord::Query] returns self
      #
      def eager_load(assoc, scope = nil, select: nil, use: nil, &eval_block)
        ref = @model ? @model.reflections[assoc.to_s] : nil
        raise "OccamsRecord: No assocation `:#{assoc}` on `#{@model&.name || '<model missing>'}`" if ref.nil?
        scope ||= -> { self.select select } if select
        @eager_loaders << eager_loader_for_association(ref).new(ref, scope, use, &eval_block)
        self
      end

      private

      # Run all defined eager loaders into the given result rows
      def eager_load!(rows)
        @eager_loaders.each { |loader|
          loader.query(rows) { |scope|
            assoc_rows = Query.new(scope, use: loader.use, query_logger: @query_logger, &loader.eval_block).run
            loader.merge! assoc_rows, rows
          }
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
