module OccamsRecord
  #
  # This module contains helpers for things you shouldn't, but sometimes must, do in legacy codebases.
  #
  module Ugly
    #
    # Loads an Occams Record object into an ActiveRecord model. THIS WILL NEGATE ALL PERFORMANCE IMPROVEMENTS!
    # The ONLY reason to use this is if you absolutely need ActiveRecord objects but still want to use Occams's
    # more advanced eager loading or find_each/find_in_batches features.
    #
    #   OccamsRecord
    #     .query(Order.order("created_at DESC"))
    #     .eager_load(:line_items, ->(q) { q.order("price") })
    #     .find_each do |o|
    #       order = OccamsRecord::Ugly.active_record(o)
    #       ...
    #     end
    #
    # @param model [ActiveRecord::Base] The model to load the record into
    # @param record [OccamsRecord::Result::Row] The OccamsRecord row
    # @return [ActiveRecord::Base]
    #
    def self.active_record(model, record)
      active = model.new(record.to_h)

      record.class.associations.each do |assoc_name|
        assoc = active.class.reflections[assoc_name]
        obj = record.send assoc_name
        next if assoc.nil? or obj.nil?

        if obj.is_a? Array
          active.send(assoc_name).load_target.replace obj.map { |x|
            active_record(assoc.klass, x)
          }
        else
          active.send "#{assoc_name}=", active_record(assoc.klass, obj)
        end
      end

      active
    end
  end
end
