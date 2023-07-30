# Eager Loading

*Docs:* [sql](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2Esql), [eager_load](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FEagerLoaders%2FBuilder:eager_load), [eager_load_many](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FEagerLoaders%2FBuilder:eager_load_many), [eager_load_one](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FEagerLoaders%2FBuilder:eager_load_one)

Unlike ActiveRecord, OccamsRecord lets you eager load associations when using hand-written SQL. There are two ways to do it.

## Using a model

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
  }.
  each { |order|
    puts order.customer.profile.username
  }
```

This works because the query is returning `orders.customer_id`, and that's the foreign key for the `Order#customer` relationship.

## Using ad hoc associations

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
  ").
  each { |order|
    puts order.customer.name
  }
```

This will take the `customer_id` column from the parent query and match it to the `id` column in the eager load query.
