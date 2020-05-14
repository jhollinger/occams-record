module OccamsRecord
  #
  # Methods for building batch finding methods. It expects "model" and "scope" methods to be present.
  #
  module Batches
    #
    # Load records in batches of N and yield each record to a block if given. If no block is given,
    # returns an Enumerator.
    #
    # NOTE Unlike ActiveRecord's find_each, ORDER BY is respected. The primary key will be appended
    # to the ORDER BY clause to help ensure consistent batches. Additionally, it will be run inside
    # of a transaction.
    #
    # @param batch_size [Integer]
    # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
    # @yield [OccamsRecord::Results::Row]
    # @return [Enumerator] will yield each record
    #
    def find_each(batch_size: 1000, use_transaction: true)
      enum = Enumerator.new { |y|
        batches(of: batch_size, use_transaction: use_transaction).each { |batch|
          batch.each { |record| y.yield record }
        }
      }
      if block_given?
        enum.each { |record| yield record }
      else
        enum
      end
    end

    #
    # Load records in batches of N and yield each batch to a block if given.
    # If no block is given, returns an Enumerator.
    #
    # NOTE Unlike ActiveRecord's find_each, ORDER BY is respected. The primary key will be appended
    # to the ORDER BY clause to help ensure consistent batches. Additionally, it will be run inside
    # of a transaction.
    #
    # @param batch_size [Integer]
    # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
    # @yield [OccamsRecord::Results::Row]
    # @return [Enumerator] will yield each batch
    #
    def find_in_batches(batch_size: 1000, use_transaction: true)
      enum = batches(of: batch_size, use_transaction: use_transaction)
      if block_given?
        enum.each { |batch| yield batch }
      else
        enum
      end
    end

    private

    #
    # Returns an Enumerator that yields batches of records, of size "of".
    # NOTE ActiveRecord 5+ provides the 'in_batches' method to do something
    # similiar, although 4.2 does not. Also it does not respect ORDER BY,
    # whereas this does.
    #
    # @param of [Integer] batch size
    # @param use_transaction [Boolean] Ensure it runs inside of a database transaction
    # @return [Enumerator] yields batches
    #
    def batches(of:, use_transaction: true)
      Enumerator.new do |y|
        if use_transaction and model.connection.open_transactions == 0
          model.connection.transaction {
            run_batches y, of
          }
        else
          run_batches y, of
        end
      end
    end

    def run_batches(y, of)
      limit = scope.limit_value
      batch_size = limit && limit < of ? limit : of

      offset = scope.offset_value || 0
      out_of_records, count = false, 0
      pkey_regex = /#{model.primary_key}|\*/ # NOTE imperfect
      order_by_pkey = !!model.primary_key &&
        (scope.select_values.empty? || scope.select_values.any? { |v| v.to_s =~ pkey_regex })

      until out_of_records
        l = limit && batch_size > limit - count ? limit - count : batch_size
        q = scope
        q = q.order(model.primary_key.to_sym) if order_by_pkey
        q = q.offset(offset).limit(l)
        results = Query.new(q, use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders).run

        y.yield results if results.any?
        count += results.size
        offset += results.size
        out_of_records = results.size < batch_size || (limit && count >= limit)
      end
    end
  end
end
