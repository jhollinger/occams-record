# Cursors

*Docs:* [find_each_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_each_with_cursor), [find_in_batches_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_in_batches_with_cursor), [cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FQuery:cursor)

*Note:* This section is only relevant to applications using PostgreSQL.

For batched loading, cursors perform better than the traditional `OFFSET & LIMIT` approach. If you're using PostgreSQL, take advantage of them with [find_each_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_each_with_cursor) and [find_in_batches_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_in_batches_with_cursor).

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer).
  find_each_with_cursor { |order|
    ...
  }
```

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer).
  find_in_batches_with_cursor { |orders|
    orders.each { |order| ... }
  }
```

If you need custom logic when using your cursor, use the lower-level [cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FQuery:cursor) method:

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer).
  cursor.
  open { |cursor|
    cursor.move(:forward, 300)
    orders = cursor.fetch(:forward, 100)
    orders.each { |order| ... }
  }
```

The `cursor` var is an instance of [OccamsRecord::Cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord/Cursor).

## Cursors with hand-written SQL

Using cursors with hand-written SQL is a breeze with [find_each_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_each_with_cursor) and [find_in_batches_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_in_batches_with_cursor).

```ruby
OccamsRecord.
  sql("
    SELECT * FROM orders
    WHERE order_date > :date
    ORDER BY order_date DESC, id
  ", {
    date: 10.years.ago
  }).
  find_each_with_cursor(batch_size: 1000) { |order|
    ...
  }
```

And you still have low-level access via [cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FQuery:cursor):

```ruby
OccamsRecord.
  sql("
    SELECT * FROM orders
    WHERE order_date > :date
    ORDER BY order_date DESC, id
  ", {
    date: 10.years.ago
  }).
  cursor.
  open { |cursor|
    cursor.move(:forward, 300)
    orders = cursor.fetch(:forward, 100)
    orders.each { |order| ... }
  }
```
