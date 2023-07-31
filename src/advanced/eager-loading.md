# Advanced Eager Loading

*Docs:* [eager_load](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FEagerLoaders%2FBuilder:eager_load)

### Select just the columns you need

Pulling back only the columns you need can be noticeably faster and use less memory, especially for wide tables.

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer, select: "id, name")
```

### Fully customize the query

You can snag the eager load's query and customize it using your model's scopes or query builder methods (`select`, `where`, `joins`, `order`, etc).

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer, ->(q) { q.active.order(:name) })
```

There's a block-based syntax that's easier to read for long queries:

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer) {
    scope { |q|
      q.active.
        joins(:account).
        where("accounts.something = ?", true).
        select("customers.id, customers.name")
    }
  }
```

### Block-argument syntax

If you need to call methods from the surrounding environment, like `params` in a Rails controller, use the block-argument syntax.

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer) { |c|
    c.scope { |q| q.where(some_column: params[:some_value]) }

    c.eager_load(:account) { |a|
      a.eager_load(:something_else)
    }
  }
```
