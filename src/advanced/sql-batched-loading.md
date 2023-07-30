# Batched Loading

*Docs:* [sql](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2Esql), [find_each](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FQuery:find_each), [find_in_batches](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FQuery:find_in_batches), [find_each_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_each_with_cursor), [find_in_batches_with_cursor](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FBatches%2FCursorHelpers:find_in_batches_with_cursor)

Unlike ActiveRecord, OccamsRecord lets you use batched loading with hand-written SQL. There are two ways to do it.

## Cursor based

If you're using PostgreSQL, using cursors for batched loading is faster and easy:

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

Read more about using [Cursors](./cursors.md#cursors-with-hand-written-sql) in OccamsRecord.

## OFFSET & LIMIT based

With other database, you'll need to fall back to the traditional (and potentially slower) `OFFSET & LIMIT` approach.

```ruby
OccamsRecord.
  sql("
    SELECT * FROM orders
    WHERE order_date > :date
    ORDER BY order_date DESC, id
    LIMIT :batch_limit
    OFFSET :batch_offset
  ", {
    date: 10.years.ago
  }).
  find_each(batch_size: 1000) { |order|
    ...
  }
```

OccamsRecord will provide the values for `:batch_limit` and `:batch_offset`. Just put the references in the right place.
