module OccamsRecord
  module BindsConverter
    #
    # A base class for converting a SQL string with Rails-style query params (?, :foo) to native Ruby format (%s, %{foo}).
    #
    # It works kind of like a tokenizer. Subclasses must 1) implement get_bind to return the converted bind
    # from the current position and 2) pass the bind sigil (e.g. ?, :) to the parent constructor.
    #
    class Abstract
      # @private
      ESCAPE = "\\".freeze

      def initialize(sql, bind_sigil)
        @sql = sql
        @end = sql.size - 1
        @start_i, @i = 0, 0
        @bind_sigil = bind_sigil
      end

      # @return [String] The converted SQL string
      def to_s
        sql = ""
        each { |frag| sql << frag }
        sql
      end

      protected

      # Yields each SQL fragment and converted bind to the given block
      def each
        escape = false
        until @i > @end
          char = @sql[@i]
          clear_escape = escape
          case char
          when @bind_sigil
            if escape
              @i += 1
            elsif @i > @start_i
              yield flush_sql
            else
              yield get_bind
            end
          when ESCAPE
            if escape
              @i += 1
            elsif @i > @start_i
              yield flush_sql
              escape = true
              @i += 1
              @start_i = @i
            else
              escape = true
              @i += 1
            end
          else
            @i += 1
          end
          escape = false if clear_escape
        end
        yield flush_sql if @i > @start_i
      end

      def flush_sql
        t = @sql[@start_i..@i - 1]
        @start_i = @i
        t
      end
    end
  end
end
