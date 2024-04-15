module OccamsRecord
  module BindsConverter
    #
    # Converts Rails-style named binds (:foo) into native Ruby format (%{foo}).
    #
    class Named
      def initialize(sql)
        @sql = sql
      end

      def to_s
        @sql.gsub(/([:\\]?):([a-zA-Z]\w*)/) do |match|
          if $1 == ":".freeze # skip PostgreSQL casts
            match # return the whole match
          elsif $1 == "\\".freeze # escaped literal colon
            match[1..-1] # return match with escaping backslash char removed
          else
            "%{#{$2}}"
          end
        end
      end
    end
  end
end
