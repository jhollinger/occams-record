module OccamsRecord
  module BindsConverter
    #
    # Converts Rails-style named binds (:foo) into native Ruby format (%{foo}).
    #
    class Named
      def initialize(sql, binds)
        @sql = sql
        @binds = binds
        @found = []
      end

      def to_s
        sql = @sql.gsub(/([:\\]?):([a-zA-Z]\w*)/) do |match|
          if $1 == ":".freeze # skip PostgreSQL casts
            match # return the whole match
          elsif $1 == "\\".freeze # escaped literal colon
            match[1..-1] # return match with escaping backslash char removed
          else
            @found << $2
            "%{#{$2}}"
          end
        end
        raise MissingBindValuesError.new(sql, missing_bind_values_msg) if @binds.size < @found.uniq.size
        sql
      end

      private

      def missing_bind_values_msg
        (@found - @binds.keys.map(&:to_s)).join(", ")
      end
    end
  end
end
