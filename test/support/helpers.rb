module TestHelpers
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

  def ar_full_version
    maj = ActiveRecord::VERSION::MAJOR
    min = ActiveRecord::VERSION::MINOR
    tin = ActiveRecord::VERSION::TINY
    "#{maj}.#{min}.#{tin}"
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
