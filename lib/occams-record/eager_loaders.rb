module OccamsRecord
  #
  # Contains eager loaders for various kinds of associations.
  #
  module EagerLoaders
    autoload :Base, 'occams-record/eager_loaders/base'
    autoload :BelongsTo, 'occams-record/eager_loaders/belongs_to'
    autoload :PolymorphicBelongsTo, 'occams-record/eager_loaders/polymorphic_belongs_to'
    autoload :HasOne, 'occams-record/eager_loaders/has_one'
    autoload :HasMany, 'occams-record/eager_loaders/has_many'
    autoload :Habtm, 'occams-record/eager_loaders/habtm'

    # Fetch the appropriate eager loader for the given association type.
    def self.fetch!(ref)
      case ref.macro
      when :belongs_to
        ref.options[:polymorphic] ? PolymorphicBelongsTo : BelongsTo
      when :has_one
        HasOne
      when :has_many
        HasMany
      when :has_and_belongs_to_many
        #EagerLoaders::Habtm
        raise 'TODO'
      else
        raise "Unsupported association type `#{macro}`"
      end
    end
  end
end
