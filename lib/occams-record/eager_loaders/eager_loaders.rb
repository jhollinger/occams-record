module OccamsRecord
  #
  # Contains eager loaders for various kinds of associations.
  #
  module EagerLoaders
    autoload :Builder, 'occams-record/eager_loaders/builder'
    autoload :Context, 'occams-record/eager_loaders/context'
    autoload :Tracer, 'occams-record/eager_loaders/tracer'

    autoload :Base, 'occams-record/eager_loaders/base'
    autoload :BelongsTo, 'occams-record/eager_loaders/belongs_to'
    autoload :PolymorphicBelongsTo, 'occams-record/eager_loaders/polymorphic_belongs_to'
    autoload :HasOne, 'occams-record/eager_loaders/has_one'
    autoload :HasMany, 'occams-record/eager_loaders/has_many'
    autoload :Habtm, 'occams-record/eager_loaders/habtm'
    autoload :Through, 'occams-record/eager_loaders/through'

    autoload :AdHocBase, 'occams-record/eager_loaders/ad_hoc_base'
    autoload :AdHocOne, 'occams-record/eager_loaders/ad_hoc_one'
    autoload :AdHocMany, 'occams-record/eager_loaders/ad_hoc_many'

    # Fetch the appropriate eager loader for the given association type.
    def self.fetch!(ref)
      case ref.macro
      when :belongs_to
        ref.polymorphic? ? PolymorphicBelongsTo : BelongsTo
      when :has_one
        HasOne
      when :has_many
        HasMany
      when :has_and_belongs_to_many
        Habtm
      else
        raise "Unsupported association type `#{macro}`"
      end
    end
  end
end
