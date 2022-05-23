module TestHelpers
  def self.load_fixtures!
    fixture_names = Dir.glob('./test/fixtures/*.yml').map { |file| Pathname.new(file).sub(/\.yml$/, '').basename }.sort
    fixture_sets = ActiveRecord::FixtureSet.create_fixtures('test/fixtures', fixture_names)
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

  def normalize_sql(sql)
    sql
      .gsub(/\s+/, " ")
      .gsub(/"/, "")
      .gsub(/`/, "")
  end

  def quote_table(x)
    ActiveRecord::Base.connection.quote_table_name x
  end

  def quote_col(x)
    ActiveRecord::Base.connection.quote_column_name x
  end
end
