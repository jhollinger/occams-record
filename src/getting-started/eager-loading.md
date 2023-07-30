# Eager Loading

*Docs:* [eager_load](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FEagerLoaders%2FBuilder:eager_load)

OccamsRecord's `eager_load` method is similar to ActiveRecord's `preload` (i.e. it uses a separate query instead of a join).

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer).
  eager_load(:line_items).
  find_each { |order|
    puts order.customer.first_name
    puts order.line_items[0].cost
  }
```

Nested eager loading is done with blocks. Isn't it so much more readable?

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer).
  eager_load(:line_items) {
    eager_load(:product)
    eager_load(:something_else) {
      eager_load(:yet_another_thing)
    }
  }.
  find_each { |order|
    puts order.customer.first_name
    order.line_items.each { |i|
      puts i.product.name
      puts i.something_else.yet_another_thing.description
    }
  }
```

There's lots more that `eager_load` can do. We'll cover it in [Advanced Eager Loading](../advanced/eager-loading.md).
