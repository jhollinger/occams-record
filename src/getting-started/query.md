# Your First Query

*Docs:* [query](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2Equery)

One thing OccamsRecord *doesn't* touch is ActiveRecord's query builder. Write your queries like normal:

```ruby
q = Order.
  completed.
  where("order_date > ?", 30.days.ago).
  order("order_date DESC")
```

But hand them off to OccamsRecord to be run:

```ruby
orders = OccamsRecord.
  query(q).
  to_a
```

Now instead of bloated ActiveRecord objects, `orders` is an array of fast, small structs.

## Batching

OccamsRecord provides [find_each](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FQuery:find_each) and [find_in_batches](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FQuery:find_in_batches) methods that work similarly to their counterparts in ActiveRecord.

```ruby
OccamsRecord.query(q).find_each { |order|
  ...
}

OccamsRecord.query(q).find_in_batches { |orders|
  orders.each { |order|
    ...
  }
}
```

If you're using PostgreSQL, consider using [find_each_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_each_with_cursor) or [find_in_batches_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_in_batches_with_cursor) for a possible performance boost. See [Cursors](../advanced/cursors.md) for more info.

## Enumeration

You may also run your query and iterate using any [Enumerable](https://ruby-doc.org/core-3.0.2/Enumerable.html) method:

```ruby
OccamsRecord.query(q).each { |order| ... }
OccamsRecord.query(q).map { |order| ... }
OccamsRecord.query(q).reduce([]) { |acc, order| ... }
```
