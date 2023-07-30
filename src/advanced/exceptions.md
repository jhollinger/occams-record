# Exceptions

## No lazy loading

As mentioned in the [introduction](../intro.md), OccamsRecord won't lazy load any associations for you. If you forget to eager load one and try to use it, it will throw an `OccamsRecord::MissingEagerLoadError` exception.

```ruby
OccamsRecord.
  query(q).
  eager_load(:line_items) {
    eager_load(:product)
  }.
  find_each { |order|
    # this throws the following exception
    puts order.line_items[0].product.category.name
  }
```

```ruby
OccamsRecord::MissingEagerLoadError: Association 'category' is unavailable on Product because it was not eager loaded! Found at root.line_items.product
```
