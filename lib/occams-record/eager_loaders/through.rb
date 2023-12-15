module OccamsRecord
  module EagerLoaders
    #
    # Handles :through associations for has_many and has_one. Polymorphic associations are not supported.
    #
    class Through < Base
      Link = Struct.new(:name, :macro, :ref, :next_ref)

      #
      # See documentation for OccamsRecord::EagerLoaders::Base.
      #
      def initialize(ref, scope = nil, use: nil, as: nil, optimizer: :select, parent: nil, active_record_fallback: nil, &builder)
        super

        unless @ref.macro == :has_one or @ref.macro == :has_many
          raise ArgumentError, "#{@ref.active_record.name}##{@ref.name} cannot be eager loaded because only `has_one` and `has_many` are supported for `through` associations"
        end
        if (polys = @ref.chain.select(&:polymorphic?)).any?
          names = polys.map { |r| "#{r.active_record.name}##{r.name}" }
          raise ArgumentError, "#{@ref.active_record.name}##{@ref.name} cannot be eager loaded because these `through` associations are polymorphic: #{names.join ', '}"
        end
        unless @optimizer == :none or @optimizer == :select
          raise ArgumentError, "Unrecognized optimizer '#{@optimizer}' (valid options are :none, :select)"
        end

        chain = @ref.chain.reverse
        @chain = chain.each_with_index.map { |x, i|
          Link.new(x.source_reflection.name, x.source_reflection.macro, x, chain[i + 1])
        }
        @chain[-1].name = @as if @as and @chain.any?
        @loader = build_loader
      end

      def through_name
        @loader.name
      end

      def run(rows, use_cursor: false, query_logger: nil, measurements: nil)
        @loader.run(rows, use_cursor: use_cursor, query_logger: query_logger, measurements: measurements)
        attr_set = "#{name}="
        rows.each do |row|
          row.send(attr_set, reduce(row))
        end
        nil
      end

      private

      # starting at the top of the chain, recurse and return the leaf node(s)
      def reduce(node, depth = 0)
        link = @chain[depth]
        case link&.macro
        when nil
          node
        when :has_many
          node.send(link.name).reduce(Set.new) { |a, child|
            result = reduce(child, depth + 1)
            case result
            when nil then a
            when Array then a + result
            else a << result
            end
          }.to_a
        when :has_one, :belongs_to
          child = node.send(link.name)
          child ? reduce(child, depth + 1) : nil
        else
          raise "Unsupported through chain link type '#{link.macro}'"
        end
      end

      # build all the nested eager loaders
      def build_loader
        head = @chain[0]
        links = @chain[1..-2]
        tail = @chain[-1]

        outer_loader = EagerLoaders.fetch!(head.ref).new(head.ref, optimized_scope(head), parent: tracer.parent)
        outer_loader.tracer.through = true

        inner_loader = links.
          reduce(outer_loader) { |loader, link|
            nested_loader = loader.nest(link.ref.source_reflection.name, optimized_scope(link))
            nested_loader.tracer.through = true
            nested_loader
          }.
          nest(tail.ref.source_reflection.name, @scopes, use: @use, as: @as, active_record_fallback: @active_record_fallback)

        @eager_loaders.each { |loader| inner_loader.eager_loaders << loader }
        inner_loader.tracer.name = tracer.name
        outer_loader
      end

      def optimized_scope(link)
        case @optimizer
        when :select
          optimized_select(link)
        when :none
          nil
        end
      end

      # only select the ids/foreign keys required to link the parent/child records
      def optimized_select(link)
        cols =
          case link.macro
          when :belongs_to
            [link.ref.association_primary_key]
          when :has_one, :has_many
            [link.ref.association_primary_key, link.ref.foreign_key]
          else
            raise "Unsupported through chain link type '#{link.macro}'"
          end

        case link.next_ref.source_reflection.macro
        when :belongs_to
          cols << link.next_ref.foreign_key
        end

        ->(q) { q.select(cols.join(", ")) }
      end
    end
  end
end
