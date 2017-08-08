module MicroRecord
  #
  # Helper for eagoer loading an association.
  #
  class EagerLoader
    # @return [String] association name
    attr_reader :name
    # @return [ActiveRecord::Base] the ActiveRecord model
    attr_reader :model
    # @return [String] name of primary key column
    attr_reader :pkey
    # @return [String] name of foreign key column
    attr_reader :fkey
    # @return [ActiveRecord::Relation] scope of the association
    attr_reader :scope

    #
    # @param ref [ActiveRecord::Association] the ActiveRecord association
    # @param scope [Proc] an optional scope to apply to the query
    #
    def initialize(ref, scope = nil)
      @name = ref.name.to_s
      @model = ref.klass
      @pkey = ref.klass.primary_key.to_s
      @fkey = ref.foreign_key.to_s
      @scope = scope ? scope.(ref.klass.all) : ref.klass.all
      @macro = ref.macro
    end

    # @return [Boolean] true if the assocation returns multiple records
    def multi?
      @macro == :has_many || @macro == :has_and_belongs_to_many
    end

    # @return [Boolean] true if the assocation returns a single record
    def single?
      !multi?
    end

    #
    # Return the SQL to load the association.
    #
    # @param primary_keys [String] Array of primary keys to search for.
    # @return [ActiveRecord::Relation]
    #
    def sql(primary_keys)
      scope.where(fkey => primary_keys).to_sql
    end

    #
    # Return the foreign key stored in the row.
    #
    # @param row [Hash] a row from the association
    # @param [Integer|String] the key to the related record
    #
    def fetch_fkey!(row)
      row.fetch fkey
    end
  end

  #
  # Overrides some behaviors of MicroRecord::EagerLoader to load associations
  # from join tables.
  #
  class HabtmEagerLoader < EagerLoader
    #
    # Return the SQL to load the association.
    #
    # @param primary_keys [String] Array of primary keys to search for.
    # @return [ActiveRecord::Relation]
    #
    def sql(primary_keys)
      # TODO cache join table results
      raise 'TODO'
      super
    end

    #
    # Return the foreign key stored in the row.
    #
    # @param row [Hash] a row from the association
    # @param [Integer|String] the key to the related record
    #
    def fetch_fkey!(row)
      # TODO look up key from cached join table results
    end
  end
end
