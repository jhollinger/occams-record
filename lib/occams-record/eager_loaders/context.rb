module OccamsRecord
  module EagerLoaders
    #
    # A container for all eager loading on a particular Active Record model. Usually the context is initialized
    # with the model, and all eager loaders are immediately initialized. Any errors (like a wrong association name
    # ) will be thrown immediately and before any queries are run.
    #
    # However, in certain situations the model cannot be known until runtime (e.g. eager loading off of a
    # polymorphic association). In these cases the model won't be set, or the eager loaders fully initialized,
    # until the parent queries have run. This means that certain errors (like a wrong association name) won't be
    # noticed until very late, after queries have started running.
    #
    class Context
      # @return [ActiveRecord::Base]
      attr_reader :model

      attr_reader :owner

      #
      # Initialize a new eager loading context.
      #
      # @param mode [ActiveRecord::Base] the model that contains the associations that will be referenced.
      # @param owner [OccamsRecord::EagerLoaders::Base] the eager loader that owns this context (if any)
      # @param polymorphic [Boolean] When true, model is allowed to change, and it's assumed that not every loader is applicable to every model.
      #
      def initialize(model = nil, owner: nil, polymorphic: false)
        @model, @polymorphic, @owner = model, polymorphic, owner
        @loaders = []
        @dynamic_loaders = []
      end

      #
      # Set the model.
      #
      # @param model [ActiveRecord::Base]
      #
      def model=(model)
        @model = model
        @loaders = @loaders + @dynamic_loaders.map { |args|
          @polymorphic ? build_loader(*args) : build_loader!(*args)
        }.compact
        @dynamic_loaders = []
      end

      #
      # Return the names of the associations being loaded.
      #
      # @return [Array<String>]
      #
      def names
        @loaders.map(&:name) |
          @loaders.select { |l| l.respond_to? :through_name }.map(&:through_name) # TODO make not hacky
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
      # @param from [Symbol] Opposite of `as`. `assoc` is the custom name and `from` is the name of association on the ActiveRecord model.
      # @param optimizer [Symbol] Only used for `through` associations. Options are :none (load all intermediate records) | :select (load all intermediate records but only SELECT the necessary columns)
      # @yield a block where you may perform eager loading on *this* association (optional)
      # @return [OccamsRecord::EagerLoaders::Base] the new loader. if @model is nil, nil will be returned.
      #
      def add(assoc, scope = nil, select: nil, use: nil, as: nil, from: nil, optimizer: :select, &builder)
        if from
          real_assoc = from
          custom_name = assoc
        elsif as
          real_assoc = assoc
          custom_name = as
        else
          real_assoc = assoc
          custom_name = nil
        end

        if @model
          loader = build_loader!(real_assoc, custom_name, scope, select, use, optimizer, builder)
          @loaders << loader
          loader
        else
          @dynamic_loaders << [real_assoc, custom_name, scope, select, use, optimizer, builder]
          nil
        end
      end

      #
      # Performs all eager loading in this context (and in any nested ones).
      #
      # @param rows [Array<ActiveRecord::Base>] the parent rows to load child rows into
      # @param query_logger [Array] optional query logger
      #
      def run!(rows, query_logger: nil, measurements: nil)
        raise "Cannot run eager loaders when @model has not been set!" if @dynamic_loaders.any? and @model.nil?
        @loaders.each { |loader|
          loader.run(rows, query_logger: query_logger, measurements: measurements)
        }
        nil
      end

      private

      def build_loader!(assoc, custom_name, scope, select, use, optimizer, builder)
        build_loader(assoc, custom_name, scope, select, use, optimizer, builder) ||
          raise("OccamsRecord: No association `:#{assoc}` on `#{@model.name}` or subclasses")
      end

      def build_loader(assoc, custom_name, scope, select, use, optimizer, builder)
        ref = @model.reflections[assoc.to_s] ||
          @model.subclasses.map(&:reflections).detect { |x| x.has_key? assoc.to_s }&.[](assoc.to_s)
        return nil if ref.nil?

        scope ||= ->(q) { q.select select } if select
        loader_class = !!ref.through_reflection ? EagerLoaders::Through : EagerLoaders.fetch!(ref)
        loader_class.new(ref, scope, use: use, as: custom_name, optimizer: optimizer, parent: @owner&.tracer, &builder)
      end
    end
  end
end
