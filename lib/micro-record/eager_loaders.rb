module MicroRecord
  #
  # Contains eager loaders for various kinds of associations.
  #
  module EagerLoaders
    autoload :Base, 'micro-record/eager_loaders/base'
    autoload :BelongsTo, 'micro-record/eager_loaders/belongs_to'
    autoload :HasOne, 'micro-record/eager_loaders/has_one'
    autoload :HasMany, 'micro-record/eager_loaders/has_many'
    autoload :Habtm, 'micro-record/eager_loaders/habtm'

    # Fetch the appropriate eager loader for the given association type.
    def self.fetch!(macro)
      case macro
      when :belongs_to
        EagerLoaders::BelongsTo
      when :has_one
        EagerLoaders::HasOne
      when :has_many
        EagerLoaders::HasMany
      when :has_and_belongs_to_many
        #EagerLoaders::Habtm
        raise 'TODO'
      else
        raise "Unsupported association type `#{macro}`"
      end
    end
  end
end
