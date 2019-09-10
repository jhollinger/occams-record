module OccamsRecord
  # Classes and methods for handing query results.
  module Results
    # ActiveRecord's internal type casting API changes from version to version.
    CASTER = case ActiveRecord::VERSION::MAJOR
             when 4 then :type_cast_from_database
             when 5, 6 then :deserialize
             else raise "OccamsRecord::Results::CASTER does yet support this version of ActiveRecord"
             end

    #
    # Dynamically build a class for a specific set of result rows. It inherits from OccamsRecord::Results::Row, and optionall prepends
    # user-defined modules.
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
        self._model = model
        self.model_name = model ? model.name : nil
        self.table_name = model ? model.table_name : nil
        self.primary_key = if model&.primary_key and (pkey = model.primary_key.to_s) and columns.include?(pkey)
                             pkey
                           end

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
  end
end
