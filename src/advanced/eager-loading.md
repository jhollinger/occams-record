# Advanced Eager Loading

*Docs:* [eager_load](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FEagerLoaders%2FBuilder:eager_load)

### Select just the columns you need

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer, select: "id, name")
```

### Fully customize the query

You can snag the eager load's pending query and use the model's scopes or add any other conditions (`select`, `where`, `joins`, `order`, etc).

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer, ->(q) { q.active.order(:name) })
```

If you have a long one, there's a block-based syntax:

```ruby
OccamsRecord.
  query(q).
  eager_load(:customer) {
    scope { |q|
      q.active.
        joins(:account).
        where("accounts.something = ?", true).
        select("id, name")
    }
  }
```

### Block-argument syntax

If you need to call methods from the surrounding environment in your eager loads (like the `params` method in a Rails controller), use the block-argument syntax.

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
