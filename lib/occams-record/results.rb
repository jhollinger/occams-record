module OccamsRecord
  # Classes and methods for handing query results.
  module Results
    # ActiveRecord's internal type casting API changes from version to version.
    CASTER = case ActiveRecord::VERSION::MAJOR
             when 4 then :type_cast_from_database
             when 5 then :deserialize
             end

    #
    # Dynamically build a class for a specific set of result rows. It inherits from OccamsRecord::Results::Row, and optionall includes
    # a user-defined module.
    #
    # @param column_names [Array<String>] the column names in the result set. The order MUST match the order returned by the query.
    # @param column_types [Hash] Column name => type from an ActiveRecord::Result
    # @param association_names [Array<String>] names of associations that will be eager loaded into the results.
    # @param model [ActiveRecord::Base] the AR model representing the table (it holds column & type info).
    # @param modules [Array<Module>] (optional)
    # @return [OccamsRecord::Results::Row] a class customized for this result set
    #
    def self.klass(column_names, column_types, association_names = [], model: nil, modules: nil)
      Class.new(Results::Row) do
        Array(modules).each { |mod| prepend mod } if modules

        self.columns = column_names.map(&:to_s)
        self.associations = association_names.map(&:to_s)
        self.model_name = model ? model.name : nil
        self.table_name = model ? model.table_name : nil
        self.primary_key = model&.primary_key&.to_s

        # Build getters & setters for associations. (We need setters b/c they're set AFTER the row is initialized
        attr_accessor(*association_names)

        # Build id getters for associations, e.g. "widget_ids" for "widgets"
        self.associations.each do |assoc|
          if (ref = model.reflections[assoc]) and !ref.polymorphic? and (ref.macro == :has_many or ref.macro == :has_and_belongs_to_many)
            pkey = ref.association_primary_key.to_sym
            define_method "#{assoc.singularize}_ids" do
              begin
                self.send(assoc).map(&pkey).uniq
              rescue NoMethodError => e
                raise MissingColumnError.new(self, e.name)
              end
            end
          end
        end if model

        # Build a getter for each attribute returned by the query. The values will be type converted on demand.
        model_column_types = model ? model.attributes_builder.types : {}
        self.columns.each_with_index do |col, idx|
          type =
            column_types[col] ||
            model_column_types[col] ||
            raise("OccamsRecord: Column `#{col}` does not exist on model `#{self.model_name}`")

          case type.type
          when :datetime
            define_method(col) { @cast_values[idx] ||= type.send(CASTER, @raw_values[idx])&.in_time_zone }
          when :boolean
            define_method(col) { @cast_values[idx] ||= type.send(CASTER, @raw_values[idx]) }
            define_method("#{col}?") { !!send(col) }
          else
            define_method(col) { @cast_values[idx] ||= type.send(CASTER, @raw_values[idx]) }
          end
        end
      end
    end

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
        # Name of Rails model
        attr_accessor :model_name
        # Name of originating database table
        attr_accessor :table_name
        # Name of primary key column (nil if column wasn't in the SELECT)
        attr_accessor :primary_key
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

      def method_missing(name, *args, &block)
        return super if args.any? or !block.nil? or self.class.model_name.nil?
        model = self.class.model_name.constantize

        if model.reflections.has_key? name.to_s
          raise MissingEagerLoadError.new(self, name)
        elsif model.columns_hash.has_key? name.to_s
          raise MissingColumnError.new(self, name)
        else
          super
        end
      end
    end
  end
end
