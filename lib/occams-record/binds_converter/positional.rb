module OccamsRecord
  module BindsConverter
    #
    # Converts Rails-style positional binds (?) into native Ruby format (%s).
    #
    class Positional < Abstract
      def initialize(sql, binds)
        super(sql, binds, "?".freeze)
      end

      private

      def get_bind
        @i += 1
        @start_i = @i
        @found << @found.size
        "%s".freeze
      end

      def missing_bind_values_msg
        (@found.size - @binds.size).to_s
      end
    end
  end
end
