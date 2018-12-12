class MultiInserter
  def initialize(table_name, columns)
    @template = "INSERT INTO #{table_name} (#{columns.join ','}) VALUES %s"
    @conn = ActiveRecord::Base.connection
  end

  def insert!(*rows)
    values = rows.map { |row|
      "(" + row.map { |val| @conn.quote val }.join(",") + ")"
    }
    sql = @template % values.join(",")
    @conn.exec_insert sql
  end
end
