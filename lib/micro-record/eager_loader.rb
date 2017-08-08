module MicroRecord
  EagerLoader = Struct.new(:name, :fkey, :base_scope) do
    def sql(primary_keys)
      base_scope.where(fkey => primary_keys).to_sql
    end
  end
end
