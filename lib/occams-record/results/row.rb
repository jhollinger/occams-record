module OccamsRecord
  module Results
    #
    # Abstract class for result rows.
    #
    # Like ActiveRecord, Boolean columns have #field? methods. However, unlike ActiveRecord,
    # other column types do NOT.
    #
    class Row
      class << self
        # Array of column names
        attr_accessor :columns
        # Array of associations names
        attr_accessor :associations
        attr_accessor :_model
        # Name of Rails model
        attr_accessor :model_name
        # Name of originating database table
        attr_accessor :table_name
        # Name of primary key column (nil if column wasn't in the SELECT)
        attr_accessor :primary_key
        # A trace of how this record was loaded (for debugging)
        attr_accessor :eager_loader_trace
        # If present, missing methods will be forwarded to the ActiveRecord model. :lazy allows lazy loading in AR, :strict doesn't
        attr_accessor :active_record_fallback
      end
      self.columns = []
      self.associations = []

      #
      # Initialize a new result row.
      #
      # @param raw_values [Array] array of raw values from db
      #
      def initialize(raw_values)
        @raw_values = raw_values
        @cast_values = {}
      end

      #
      # Hash-like accessor for attributes and associations.
      #
      # @param attr [String|Symbol]
      # @return [Object]
      #
      def [](attr)
        respond_to?(attr) ? send(attr) : nil
      end

      #
      # Returns true if the two objects are from the same table and have the same primary key.
      #
      # @param obj [OccamsRecord::Results::Row]
      # @return [Boolean]
      #
      def ==(obj)
        super ||
          obj.is_a?(OccamsRecord::Results::Row) &&
          obj.class.table_name && obj.class.table_name == self.class.table_name &&
          (pkey1 = obj.class.primary_key) && (pkey2 = self.class.primary_key) &&
          obj.send(pkey1) == self.send(pkey2)
      end

      #
      # Return row as a Hash. By default the hash does NOT include associations.
      #
      # @param symbolize_names [Boolean] if true, make Hash keys Symbols instead of Strings
      # @param recursive [Boolean] if true, include assiciations and them (and their associations) to hashes.
      # @return [Hash] a Hash with String or Symbol keys
      #
      def to_h(symbolize_names: false, recursive: false)
        hash = self.class.columns.each_with_object({}) { |col_name, acc|
          key = symbolize_names ? col_name.to_sym : col_name
          acc[key] = send col_name
        }

        recursive ? self.class.associations.each_with_object(hash) { |assoc_name, acc|
          key = symbolize_names ? assoc_name.to_sym : assoc_name
          assoc = send assoc_name
          acc[key] =
            if assoc.is_a? Array
              assoc.map { |x| x.to_h(symbolize_names: symbolize_names, recursive: true) }
            elsif assoc
              assoc.to_h(symbolize_names: symbolize_names, recursive: true)
            end
        } : hash
      end

      alias_method :to_hash, :to_h
      alias_method :attributes, :to_h

      #
      # Returns the name of the model and the attributes.
      #
      # @return [String]
      #
      def to_s
        "#{self.class.model_name || "Anonymous"}#{to_h(symbolize_names: true, recursive: false)}"
      end

      #
      # Returns a string with the "real" model name and raw result values.
      #
      # Weird note - if this string is longer than 65 chars it won't be used in exception messages.
      # https://bugs.ruby-lang.org/issues/8982
      #
      # @return [String]
      #
      def inspect
        id = self.class.primary_key ? send(self.class.primary_key) : "none"
        "#<#{self.class.model_name || "Anonymous"} #{self.class.primary_key}: #{id}>"
      end

      IDS_SUFFIX = /_ids$/
      def method_missing(name, *args, &block)
        model = self.class._model
        ex = NoMethodError.new("Undefined method `#{name}' for #{self.inspect}. Occams Record trace: #{self.class.eager_loader_trace}", name, args)
        raise ex if model.nil?

        name_str = name.to_s
        assoc = name_str.sub(IDS_SUFFIX, "").pluralize
        no_args = args.empty? && block.nil?

        if no_args and name_str =~ IDS_SUFFIX and can_define_ids_reader? assoc
          define_ids_reader! assoc
          send name
        elsif no_args and model.reflections.has_key? name_str
          raise MissingEagerLoadError.new(self, name)
        elsif no_args and model.columns_hash.has_key? name_str
          raise MissingColumnError.new(self, name)
        elsif self.class.active_record_fallback
          active_record_fallback(name, *args, &block)
        else
          raise ex
        end
      end

      def respond_to_missing?(name, _include_private = false)
        model = self.class._model
        return super if model.nil?

        name_str = name.to_s
        assoc = name_str.sub(IDS_SUFFIX, "").pluralize
        if name_str =~ IDS_SUFFIX and can_define_ids_reader? assoc
          true
        else
          super
        end
      end

      private

      def active_record_fallback(name, *args, &block)
        @active_record_fallback ||= Ugly::active_record(self.class._model, self).tap { |record|
          record.strict_loading! if self.class.active_record_fallback == :strict
        }
        @active_record_fallback.send(name, *args, &block)
      rescue NoMethodError => e
        raise NoMethodError.new("#{e.message}. Occams Record trace: #{self.class.eager_loader_trace}.active_record_fallback(#{self.class._model.name})", name, args)
      end

      def can_define_ids_reader?(assoc)
        model = self.class._model
        self.class.associations.include?(assoc) &&
         (ref = model.reflections[assoc]) &&
         !ref.polymorphic? &&
         (ref.macro == :has_many || ref.macro == :has_and_belongs_to_many)
      end

      def define_ids_reader!(assoc)
        model = self.class._model
        ref = model.reflections[assoc]
        pkey = ref.klass.primary_key.to_sym

        self.class.class_eval do
          define_method "#{assoc.singularize}_ids" do
            begin
              self.send(assoc).map(&pkey).uniq
            rescue NoMethodError => e
              raise MissingColumnError.new(self, e.name)
            end
          end
        end
      end
    end
  end
end
