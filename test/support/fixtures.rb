require 'active_record/fixtures'

module Fixtures
  def self.load!
    fixture_names = Dir.glob('./test/fixtures/*.yml').map { |file| Pathname.new(file).sub(/\.yml$/, '').basename }.sort
    fixture_sets = nil
    ActiveRecord::Base.connection.disable_referential_integrity do
      fixture_sets = ActiveRecord::FixtureSet.create_fixtures('test/fixtures', fixture_names)
    end

    fixture_sets.each do |set|
      TestHelpers.class_eval do
        define_method set.name do |record_name|
          model = set.model_class
          id = set[record_name.to_s][model.primary_key.to_s]
          model.find(id)
        end
      end
    end
  end
end
