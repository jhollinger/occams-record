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

        # Build getters & setters for associations. (We need setters b/c they're set AFTER the row is initialized
        attr_accessor(*association_names)

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
    class Row
      class << self
        # Array of column names
        attr_accessor :columns
        # Array of associations names
        attr_accessor :associations
        # Name of Rails model
        attr_accessor :model_name
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
      # Return row as a Hash (recursive).
      #
      # @param symbolize_names [Boolean] if true, make Hash keys Symbols instead of Strings
      # @return [Hash] a Hash with String or Symbol keys
      #
      def to_h(symbolize_names: false)
        hash = self.class.columns.reduce({}) { |a, col_name|
          key = symbolize_names ? col_name.to_sym : col_name
          a[key] = send col_name
          a
        }

        self.class.associations.reduce(hash) { |a, assoc_name|
          key = symbolize_names ? assoc_name.to_sym : assoc_name
          assoc = send assoc_name
          a[key] = if assoc.is_a? Array
                     assoc.map { |x| x.to_h(symbolize_names: symbolize_names) }
                   elsif assoc
                     assoc.to_h(symbolize_names: symbolize_names)
                   end
          a
        }
      end

      alias_method :to_hash, :to_h

      def method_missing(name, *args, &block)
        return super if args.any? or !block.nil?
        model = self.class.model_name.constantize

        if model.reflections.has_key? name.to_s
          raise MissingEagerLoadError.new(model.name, name)
        elsif model.columns_hash.has_key? name.to_s
          raise MissingColumnSelectError.new(model.name, name)
        else
          super
        end
      end

      #
      # Returns a string with the "real" model name and raw result values.
      #
      # @return [String]
      #
      def inspect
        "#<OccamsRecord::Results::Row @model_name=#{self.class.model_name} @raw_values=#{@raw_values}>"
      end
    end

    # Exception when an unloaded association is called on a result row
    class MissingEagerLoadError < StandardError
      attr_reader :model_name
      attr_reader :name

      def initialize(model_name, name)
        @model_name, @name = model_name, name
      end

      def message
        "The association '#{name}' is unavailable on #{model_name} because it has not been eager loaded!"
      end
    end

    # Exception when an unselected column is called on a result row
    class MissingColumnSelectError < StandardError
      attr_reader :model_name
      attr_reader :name

      def initialize(model_name, name)
        @model_name, @name = model_name, name
      end

      def message
        "The column '#{name}' is unavailable on #{model_name} because it was not included in the SELECT statement!"
      end
    end
  end
end
