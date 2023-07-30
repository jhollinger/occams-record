# Hand-written SQL

*Docs:* [sql](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2Esql)

Sometimes you have to write a big, gnarly SQL query by hand. Here's a basic example (using simple SQL for brevity):

```ruby
OccamsRecord.
  sql("
    SELECT * FROM orders
    WHERE order_date > :date
    ORDER BY order_date DESC, id
  ", {
    date: 30.days.ago
  }).
  each { |order|
     ...
  }
```

OccamsRecord supports several query param syntaxes:

```ruby
# Rails-style
OccamsRecord.sql("SELECT ... WHERE orders.date > :date", {date: date})
OccamsRecord.sql("SELECT ... WHERE orders.date > ?", [date])

# Ruby-style
OccamsRecord.sql("SELECT ... WHERE orders.date > %{date}", {date: date})
OccamsRecord.sql("SELECT ... WHERE orders.date > %s", [date])
```

## Eager loading

Unlike ActiveRecord, OccamsRecord lets you eager load associations when using hand-written SQL. There are two ways to do it.

### Using a model

If your results are close enough to a model, you can annotate the query with the model and `eager_load` its associations.

```ruby
OccamsRecord.
  sql("
    SELECT * FROM orders
    WHERE order_date > :date
    ORDER BY order_date DESC, id
  ", {
    date: 30.days.ago
  }).
  model(Order).
  eager_load(:customer) {
    eager_load(:profile)
  }
```

This works because the query is returning `orders.customer_id`, and that's the foreign key for the `Order#customer` relationship.

### Using ad hoc associations

If your results don't resemble a model, or you need to load associations from various models, you can write the SQL yourself in an "ad hoc association". See [Ad Hoc Associations](./ad-hoc-associations.md) for more details.

```ruby
OccamsRecord.
  sql("
    SELECT * FROM orders
    WHERE order_date > :date
    ORDER BY order_date DESC, id
  ", {
    date: 30.days.ago
  }).
  eager_load_one(:customer, {:customer_id => :id}, "
    SELECT * FROM customers
    WHERE id IN (:customer_ids)
  ")
```

## Batched loading

Unlike ActiveRecord, OccamsRecord lets you use batched loading with hand-written SQL. There are two ways to do it.

### Cursor based

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
  find_each_with_cursor(batch_size: 1000) do |order|
    ...
  end
```

Read more about using [Cursors](./cursors.md) in OccamsRecord.

### OFFSET & LIMIT based

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
  find_each(batch_size: 1000) do |order|
    ...
  end
```

OccamsRecord will provide the values for `:batch_limit` and `:batch_offset`. Just put the references in the right place.
