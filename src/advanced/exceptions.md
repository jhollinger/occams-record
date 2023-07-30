# Exceptions

Aside from various possible `RuntimeError` and `ArgumentError` exceptions, OccamsRecord has several well-defined exceptions for common errors. The most useful are described here.

## OccamsRecord::MissingEagerLoadError

As mentioned in the [introduction](../intro.md), OccamsRecord won't lazy load any associations for you. If you forget to eager load one and try to use it, it will throw an `OccamsRecord::MissingEagerLoadError` exception.

```ruby
OccamsRecord.
  query(q).
  eager_load(:line_items) {
    eager_load(:product)
  }.
  find_each { |order|
    # this throws because it tries to access "category", which we didn't eager load
    puts order.line_items[0].product.category.name
  }
```

The message contains helpful information telling us exactly where we forgot to eager load it:

> Association 'category' is unavailable on Product because it was not eager loaded! Occams Record trace: root.line_items.product

## OccamsRecord::MissingColumnError

Elsewhere we noted that your eager loads can specify a subset of columns to select (for performance reasons). If you try to access a column you didn't select, it will throw an `OccamsRecord::MissingColumnError` exception.

```ruby
OccamsRecord.
  query(q).
  eager_load(:line_items) {
    eager_load(:product, select: "id, name")
  }.
  find_each { |order|
    # this throws because it tries to access the "description" column, which we didn't select
    puts order.line_items[0].product.description
  }
```

The message contains helpful information telling us exactly where we forgot to select it:

> Column 'description' is unavailable on Product because it was not included in the SELECT statement! Occams Record trace: root.line_items.product"
