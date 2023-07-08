module OccamsRecord
  # Classes and methods for handing query results.
  module Results
    #
    # Dynamically build a class for a specific set of result rows. It inherits from OccamsRecord::Results::Row, and optionall prepends
    # user-defined modules.
    #
    # @param column_names [Array<String>] the column names in the result set. The order MUST match the order returned by the query.
    # @param column_types [Hash] Column name => type from an ActiveRecord::Result
    # @param association_names [Array<String>] names of associations that will be eager loaded into the results.
    # @param model [ActiveRecord::Base] the AR model representing the table (it holds column & type info).
    # @param modules [Array<Module>] (optional)
    # @param tracer [OccamsRecord::EagerLoaders::Tracer] the eager loaded that loaded this class of records
    # @param active_record_fallback [Symbol] If passed, missing methods will be forwarded to an ActiveRecord instance. Options are :lazy (allow lazy loading in the AR record) or :strict (require strict loading)
    # @return [OccamsRecord::Results::Row] a class customized for this result set
    #
    def self.klass(column_names, column_types, association_names = [], model: nil, modules: nil, tracer: nil, active_record_fallback: nil)
      raise ArgumentError, "Invalid active_record_fallback option :#{active_record_fallback}. Valid options are :lazy, :strict" if active_record_fallback and !%i(lazy strict).include?(active_record_fallback)
      raise ArgumentError, "Option active_record_fallback is not allowed when no model is present" if active_record_fallback and model.nil?

      Class.new(Results::Row) do
        Array(modules).each { |mod| prepend mod } if modules

        self.columns = column_names.map(&:to_s)
        self.associations = association_names.map(&:to_s)
        self._model = model
        self.model_name = model ? model.name : nil
        self.table_name = model ? model.table_name : nil
        self.eager_loader_trace = tracer
        self.active_record_fallback = active_record_fallback
        self.primary_key =
          if model&.primary_key and (pkey = model.primary_key.to_s) and columns.include?(pkey)
            pkey
          end

        # Build getters & setters for associations. (We need setters b/c they're set AFTER the row is initialized
        attr_accessor(*association_names)

        # Build a getter for each attribute returned by the query. The values will be type converted on demand.
        casters = TypeCaster.generate(column_names, column_types, model: model)
        self.columns.each_with_index do |col, idx|
          caster = casters[col]

          if caster
            define_method(col) {
              @cast_values[idx] = caster.(@raw_values[idx]) unless @cast_values.has_key?(idx)
              @cast_values[idx]
            }
          else
            define_method(col) {
              @raw_values[idx]
            }
          end

          define_method("#{col}?") { send(col).present? }
        end
      end
    end
  end
end
