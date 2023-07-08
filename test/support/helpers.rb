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

  def pg?
    !!(ActiveRecord::Base.connection.class.name =~ /postgres/i)
  end

  def sqlite?
    !!(ActiveRecord::Base.connection.class.name =~ /sqlite/i)
  end

  def mysql?
    !!(ActiveRecord::Base.connection.class.name =~ /mysql/i)
  end

  def ar_version
    ActiveRecord::VERSION::MAJOR
  end

  def normalize_sql(sql)
    sql
      .gsub(/\s+/, " ")
      .gsub(/"/, "")
      .gsub(/`/, "")
      .gsub(/ IN \([^)]+\)/) { |match|
        match.sub!(/^ IN \(/, "")
        match.sub!(/\)$/, "")
        items = match.split(",").map(&:strip).map { |v|
          v =~ /^\d+$/ ? v.to_i : v
        }.sort
        " IN (#{items.join ", "})"
      }
  end
end
