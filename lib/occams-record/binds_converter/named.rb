module OccamsRecord
  module BindsConverter
    # @private
    WORD = /\w/

    #
    # Converts Rails-style named binds (:foo) into native Ruby format (%{foo}).
    #
    class Named < Abstract
      def initialize(sql)
        super(sql, ":".freeze)
      end

      protected

      def get_bind
        old_i = @i
        @i += 1
        @start_i = @i

        until @i > @end or @sql[@i] !~ WORD
          @i += 1
        end

        if @i > @start_i
          name = @sql[@start_i..@i - 1]
          @start_i = @i
          "%{#{name}}"
        else
          @sql[old_i]
        end
      end
    end
  end
end
