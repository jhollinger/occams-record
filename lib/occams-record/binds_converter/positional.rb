module OccamsRecord
  module BindsConverter
    #
    # Converts Rails-style positional binds (?) into native Ruby format (%s).
    #
    class Positional < Abstract
      def initialize(sql)
        super(sql, "?".freeze)
      end

      protected

      def get_bind
        @i += 1
        @start_i = @i
        "%s".freeze
      end
    end
  end
end
