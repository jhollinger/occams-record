module OccamsRecord
  module EagerLoaders
    class Context
      # @return [ActiveRecord::Base]
      attr_accessor :model

      #
      # Initialize a new eager loading context.
      #
      # @param mode [ActiveRecord::Base] the model that contains the associations that will be referenced.
      #
      def initialize(model = nil)
        @model = model
        @loaders = []
        @dynamic_loaders = []
      end

      #
      # Return the names of the associations being loaded.
      #
      # @return [Array<String>]
      #
      def names
        @loaders.map(&:name) + @dynamic_loaders.map(&:first)
      end

      #
      # Append an already-initialized eager loader.
      #
      # @param loader [OccamsRecord::EagerLoaders::Base]
      # @return [OccamsRecord::EagerLoaders::Base] the added loader
      #
      def <<(loader)
        @loaders << loader
        loader
      end

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
      # @return [OccamsRecord::EagerLoaders::Base] the new loader. if @model is nil, nil will be returned.
      #
      def add(assoc, scope = nil, select: nil, use: nil, as: nil, &builder)
        if @model
          loader = build_loader(assoc, scope, select, use, as, builder)
          @loaders << loader
          loader
        else
          @dynamic_loaders << [assoc, scope, select, use, as, builder]
          nil
        end
      end

      #
      # Performs all eager loading in this context (and in any nested ones).
      #
      # @param rows [Array<ActiveRecord::Base>] the parent rows to load child rows into
      # @param query_logger [Array] optional query logger
      #
      def run!(rows, query_logger: nil)
        @loaders.each { |loader|
          loader.run(rows, query_logger: query_logger)
        }
        @dynamic_loaders.each { |args|
          loader = build_loader(*args)
          loader.run(rows, query_logger: query_logger)
        }
        nil
      end

      private

      def build_loader(assoc, scope, select, use, as, builder)
        ref = @model ? @model.reflections[assoc.to_s] : nil
        ref ||= @model.subclasses.map(&:reflections).detect { |x| x.has_key? assoc.to_s }&.[](assoc.to_s) if @model
        raise "OccamsRecord: No assocation `:#{assoc}` on `#{@model&.name || '<model missing>'}` or subclasses" if ref.nil?
        scope ||= ->(q) { q.select select } if select
        loader_class = EagerLoaders.fetch!(ref)
        loader_class.new(ref, scope, use: use, as: as, &builder)
      end
    end
  end
end
