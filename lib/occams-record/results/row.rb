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
      # @param attr [String|Symbol\
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
        hash = self.class.columns.reduce({}) { |a, col_name|
          key = symbolize_names ? col_name.to_sym : col_name
          a[key] = send col_name
          a
        }

        recursive ? self.class.associations.reduce(hash) { |a, assoc_name|
          key = symbolize_names ? assoc_name.to_sym : assoc_name
          assoc = send assoc_name
          a[key] = if assoc.is_a? Array
                     assoc.map { |x| x.to_h(symbolize_names: symbolize_names, recursive: true) }
                   elsif assoc
                     assoc.to_h(symbolize_names: symbolize_names, recursive: true)
                   end
          a
        } : hash
      end

      alias_method :to_hash, :to_h

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
        ex = NoMethodError.new("Undefined method `#{name}' for #{self.inspect}. Found at #{self.class.eager_loader_trace}", name, args)
        raise ex if args.any? or !block.nil? or model.nil?

        name_str = name.to_s
        assoc = name_str.sub(IDS_SUFFIX, "").pluralize
        if name_str =~ IDS_SUFFIX and can_define_ids_reader? assoc
          define_ids_reader! assoc
          send name
        elsif model.reflections.has_key? name_str
          raise MissingEagerLoadError.new(self, name)
        elsif model.columns_hash.has_key? name_str
          raise MissingColumnError.new(self, name)
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
