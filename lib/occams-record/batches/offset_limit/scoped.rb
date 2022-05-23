module OccamsRecord
  #
  # Methods for building batch finding methods. It expects "model" and "scope" methods to be present.
  #
  module Batches
    module OffsetLimit
      class Scoped
        def initialize(model, scope, use: nil, query_logger: nil, eager_loaders: nil)
          @model, @scope = model, scope
          @use, @query_logger, @eager_loaders = use, query_logger, eager_loaders
        end

        #
        # Returns an Enumerator that yields batches of records, of size "of".
        # NOTE ActiveRecord 5+ provides the 'in_batches' method to do something
        # similiar, although 4.2 does not. Also it does not respect ORDER BY,
        # whereas this does.
        #
        # @param batch_size [Integer] batch size
        # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
        # @param append_order_by [String] Append this column to ORDER BY to ensure consistent results. Defaults to the primary key. Pass false to disable.
        # @return [Enumerator] yields batches
        #
        def enum(batch_size:, use_transaction: true, append_order_by: nil)
          append_order =
            case append_order_by
            when false then nil
            when nil then @model.primary_key
            else append_order_by
            end

          Enumerator.new do |y|
            if use_transaction and @model.connection.open_transactions == 0
              @model.connection.transaction {
                run_batches y, batch_size, append_order
              }
            else
              run_batches y, batch_size, append_order
            end
          end
        end

        private

        def run_batches(y, of, append_order_by = nil)
          limit = @scope.limit_value
          batch_size = limit && limit < of ? limit : of

          offset = @scope.offset_value || 0
          out_of_records, count = false, 0
          order_by =
            if append_order_by
              append_order_by.to_s == @model.primary_key.to_s ? append_order_by.to_sym : append_order_by
            end

          until out_of_records
            l = limit && batch_size > limit - count ? limit - count : batch_size
            q = @scope
            q = q.order(order_by) if order_by
            q = q.offset(offset).limit(l)
            results = ::OccamsRecord::Query.new(q, use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders).run

            y.yield results if results.any?
            count += results.size
            offset += results.size
            out_of_records = results.size < batch_size || (limit && count >= limit)
          end
        end
      end
    end
  end
end
