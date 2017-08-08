module MicroRecord
  #
  # Module containing eagier loaders for different types of associations.
  #
  module EagerLoader
    #
    # Base class for eager loaders.
    #
    class Base
      # @return [String] association name
      attr_reader :name
      # @return [String] name of foreign key column
      attr_reader :fkey
      # @return [ActiveRecord::Relation] base scope of the association
      attr_reader :base_scope

      class << self
        # @return [Boolean] true if the assocation returns multiple records
        attr_accessor :many
      end

      #
      # @param name [String] association name
      # @param fkey [String] name of foreign key column
      # @param base_scope [ActiveRecord::Relation] base scope of the association
      #
      def initialize(name, fkey, base_scope)
        @name, @fkey, @base_scope = name, fkey, base_scope
      end

      # @return [Boolean] true if this assocation returns multiple records
      def many
        self.class.many
      end

      def sql(primary_keys)
        base_scope.where(fkey => primary_keys).to_sql
      end
    end

    # Eager load for belongs_to and has_one associations.
    class BelongsTo < Base
      self.many = false
    end

    # Eager loader for has_many associations.
    class HasMany < Base
      self.many = true
    end

    # Eager loader for has_and_belongs_to_many associations.
    # TODO figure out how to map the results back to the main records.
    class HABTM < Base
      self.many = true
    end
  end
end
