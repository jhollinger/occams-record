module OccamsRecord
  #
  # Methods for building batch finding methods. It expects "model" and "scope" methods to be present.
  #
  module Batches
    #
    # Load records in batches of N and yield each record to a block if given.
    # If no block is given, returns an Enumerator.
    #
    # NOTE Unlike ActiveRecord's find_each, order is respected. The primary key will be appended
    # to the ORDER BY clause to help ensure consistent batches. HOWEVER, it's still possible for
    # batches to be "corrupted" (miss records or repeat records) if table data changes out from
    # enderneath them. To prevent this, it's strongly recomended to always run find_each inside
    # of a transaction.
    #
    # @param batch_size [Integer]
    # @yield [OccamsRecord::Results::Row]
    # @return [Enumerator] will yield each record
    #
    def find_each(batch_size: 1000)
      enum = Enumerator.new { |y|
        batches(of: batch_size).each { |batch|
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
    # NOTE Unlike ActiveRecord's find_in_batches, order is respected. The primary key will be appended
    # to the ORDER BY clause to help ensure consistent batches. HOWEVER, it's still possible for
    # batches to be "corrupted" (miss records or repeat records) if table data changes out from
    # enderneath them. To prevent this, it's strongly recomended to always run find_in_batches inside
    # of a transaction.
    #
    # @param batch_size [Integer]
    # @yield [OccamsRecord::Results::Row]
    # @return [Enumerator] will yield each batch
    #
    def find_in_batches(batch_size: 1000)
      enum = batches(of: batch_size)
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
    # @return [Enumerator] yields batches
    #
    def batches(of:)
      if model.connection.open_transactions == 0
        $stderr.puts "Occams Record Warning: find_each or find_in_batches is being run outside of transaction. Batch consistency can only be ensured within a transaction."
      end

      limit = scope.limit_value
      batch_size = limit && limit < of ? limit : of
      Enumerator.new do |y|
        offset = scope.offset_value || 0
        out_of_records, count = false, 0

        until out_of_records
          l = limit && batch_size > limit - count ? limit - count : batch_size
          q = scope.order(model.primary_key.to_sym).offset(offset).limit(l)
          results = Query.new(q, use: @use, query_logger: @query_logger, eager_loaders: @eager_loaders).run

          y.yield results if results.any?
          count += results.size
          offset += results.size
          out_of_records = results.size < batch_size || (limit && count >= limit)
        end
      end
    end
  end
end
