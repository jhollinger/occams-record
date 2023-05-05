---
layout: default
title: Occams Record
description: The missing high-efficiency query API for ActiveRecord
---
# Occams Record

> Do not multiply entities beyond necessity. -- Occam's Razor

Full documentation is available at [rubydoc.info/gems/occams-record](http://www.rubydoc.info/gems/occams-record).

OccamsRecord is a high-efficiency, advanced query library for use alongside ActiveRecord. It is **not** an ORM or an ActiveRecord replacement. OccamsRecord can breathe fresh life into your ActiveRecord app by giving it two things:

### 1) Huge performance gains

* 3x-5x faster than ActiveRecord queries, *minimum*.
* Uses 1/3 the memory of ActiveRecord query results.
* Eliminates the N+1 query problem. (This often exceeds the baseline 3x-5x gain.)

### 2) Supercharged querying & eager loading

* Customize the SQL used to eager load associations (order them, apply filters, etc)
* Use cursors (Postgres only)
* Use `ORDER BY` with `find_each`/`find_in_batches`
* Use `find_each`/`find_in_batches` with raw SQL
* Eager load associations off of raw SQL queries
* Use `pluck` with raw SQL queries

### How does OccamsRecord do all this?
[Look over the speed and memory measurements yourself!](https://github.com/jhollinger/occams-record/wiki/Measurements) OccamsRecord achieves all of this by making some **very specific trade-offs:**

* OccamsRecord results are *read-only*.
* OccamsRecord results are *purely database rows* - they don't have any instance methods from your Rails models.
* You *must eager load* each assocation you intend to use. If you try to use one you didn't eager load, an exception will be raised.

# Overview

Full documentation is available at [rubydoc.info/gems/occams-record](http://www.rubydoc.info/gems/occams-record). Code lives at at [github.com/jhollinger/occams-record](https://github.com/jhollinger/occams-record). Contributions welcome!

Simply add `occams-record` to your `Gemfile`:

```ruby
gem 'occams-record'
```

Build your queries like normal, using ActiveRecord's excellent query builder. Then pass them off to Occams Record.

```ruby
q = Order
  .completed
  .where("order_date > ?", 30.days.ago)
  .order("order_date DESC")

orders = OccamsRecord
  .query(q)
  .run
````

`each`, `map`, `reduce`, and other Enumerable methods may be used instead of *run*. `find_each` and `find_in_batches` are also supported, and unlike in ActiveRecord, `ORDER BY` works as you'd expect.

Occams Record has great support for raw SQL queries too, but we'll get to those later.

## Basic eager loading

Eager loading is similiar to ActiveRecord's `preload`: each association is loaded in a separate query. Unlike ActiveRecord, nested associations use blocks instead of Hashes. More importantly, if you try to use an association you didn't eager load *an exception will be raised*. In other words, the N+1 query problem simply doesn't exist.

```ruby
OccamsRecord
  .query(q)
  .eager_load(:customer)
  .eager_load(:line_items) { |l|
    l.eager_load(:product)
    l.eager_load(:something_else)
  }
  .find_each { |order|
    puts order.customer.name
    order.line_items.each { |line_item|
      puts line_item.product.name
      puts line_item.product.category.name
      OccamsRecord::MissingEagerLoadError: Association 'category' is unavailable on Product because it was not eager loaded! Found at root.line_items.product
    }
  }
```

## Advanced eager loading

Occams Record allows you to tweak the SQL of any eager load. Pull back only the columns you need, change the order, add a `WHERE` clause, etc.

```ruby
orders = OccamsRecord
  .query(q)
  # Only SELECT the columns you need. Your DBA will thank you.
  .eager_load(:customer, select: "id, name")

  # Or use 'scope' to access the full power of ActiveRecord's query builder.
  # Here, only 'active' line items will be returned, and in a specific order.
  .eager_load(:line_items) { |l|
    l.scope { |q| q.active.order("created_at") }

    l.eager_load(:product)
    l.eager_load(:something_else)
  }
  .run
```

Occams Record also supports loading ad hoc associations using raw SQL. We'll get to that in a later section.

## Query with cursors

`find_each_with_cursor`/`find_in_batches_with_cursor` work like `find_each`/`find_in_batches`, except they use cursors. For large data sets, cursors offer a noticible speed boost. Postgres only.

```ruby
OccamsRecord
  .query(q)
  .eager_load(:customer)
  .find_each_with_cursor do |order|
    ...
  end
```

The `cursor.open` method allows lower level access to cursor behavior. See `OccamsRecord::Cursor` for more info.

```ruby
orders = OccamsRecord
  .query(q)
  .eager_load(:customer)
  .cursor
  .open do |cursor|
    cursor.move(:forward, 300)
    cursor.fetch(:forward, 100)
  end
```

## Raw SQL queries

ActiveRecord has raw SQL escape hatches like `find_by_sql` and `exec_query`, but they give up critical features like eager loading and `find_each`/`find_in_batches`. Occams Record's escape hatches don't make you give up anything.

**Batched loading with cursors**

`find_each_with_cursor`, `find_in_batches_with_cursor`, and `cursor.open` are all available.

```ruby
OccamsRecord
  .sql("
    SELECT * FROM orders
    WHERE order_date > %{date}
    ORDER BY order_date DESC, id
  ", {
    date: 10.years.ago
  })
  .find_each_with_cursor(batch_size: 1000) do |order|
    ...
  end
```

**Batched loading without cursors**

If your database doesn't support cursors, you can use `find_each`/`find_in_batches`. Just provide `LIMIT` and `OFFSET` (see below), and Occams will plug in the right numbers.

```ruby
OccamsRecord
  .sql("
    SELECT * FROM orders
    WHERE order_date > %{date}
    ORDER BY order_date DESC, id
    LIMIT %{batch_limit}
    OFFSET %{batch_offset}
  ", {
    date: 10.years.ago
  })
  .find_each(batch_size: 1000) do |order|
    ...
  end
```

**Eager loading**

To use `eager_load` with a raw SQL query you must tell Occams what the base model is. (That doesn't apply if you're loading an ad hoc, raw SQL association. We'll get to those next.)

```ruby
orders = OccamsRecord
  .sql("
    SELECT * FROM orders
    WHERE order_date > %{date}
    ORDER BY order_date DESC, id
  ", {
    date: 30.days.ago
  })
  .model(Order)
  .eager_load(:customer)
  .run
```

## Raw SQL eager loading

Let's say we want to load each product with an array of all customers who've ordered it. We *could* do that by loading various nested associations:

```ruby
products_with_orders = OccamsRecord
  .query(Product.all)
  .eager_load(:line_items) { |l|
    l.eager_load(:order) { |l|
      l.eager_load(:customer)
    }
  }
  .map { |product|
    customers = product.line_items.map(&:order).map(&:customer).uniq
    [product, customers]
  }
```

But that's very wasteful. Occams gives us better options: `eager_load_many` and `eager_load_one`.

```ruby
products = OccamsRecord
  .query(Product.all)
  .eager_load_many(:customers, {:id => :product_id}, "
    SELECT DISTINCT product_id, customers.*
    FROM line_items
      INNER JOIN orders ON line_items.order_id = orders.id
      INNER JOIN customers on orders.customer_id = customers.id
    WHERE line_items.product_id IN (%{ids})
  ", binds: {
    # additional bind values (ids will be passed in for you)
  })
  .run
```

`eager_load_many` is declaring an ad hoc *has_many* association called *customers*. The `{:id => :product_id}` Hash defines the mapping: *id* in the parent record maps to *product_id* in the child records.

The SQL string and binds should be familiar. `%{ids}` will be provided for you - just stick it in the right place. Note that it won't always be called *ids*; the name will be the plural version of the key in your mapping.

`eager_load_one` defines an ad hoc `has_one`/`belongs_to` association. It and `eager_load_many` are available with both `OccamsRecord.query` and `OccamsRecord.sql`.

## Injecting instance methods

Occams Records results are just plain rows; there are no methods from your Rails models. (Separating your persistence layer from your domain is good thing!) But sometimes you need a few methods. Occams Record provides two ways of accomplishing this.

### Include custom modules

You may also specify one or more modules to be included in your results:

```ruby
module MyOrderMethods
  def description
    "#{order_number} - #{date}"
  end
end

module MyProductMethods
  def expensive?
    price > 100
  end
end

orders = OccamsRecord
  .query(Order.all, use: MyOrderMethods)
  .eager_load(:line_items) {
    eager_load(:product, use: [MyProductMethods, OtherMethods])
  }
  .run
```

### ActiveRecord method fallback

This is an ugly hack of last resort if you can't easily extract a method from your model into a shared module. Plugins, like `carrierwave`, are a good example. When you call a method that doesn't exist on an Occams Record result, it will initialize an ActiveRecord object and forward the method call to it.

The `active_record_fallback` option must be passed either `:lazy` or `:strict` (recommended). `:strict` enables ActiveRecord's strict loading option, helping you avoid N+1 queries. :lazy allows them. Note that `:strict` is only available for ActiveRecord 6.1 and later.

The following will forward any nonexistent methods for `Order` and `Product` records:

```ruby
orders = OccamsRecord
  .query(Order.all, active_record_fallback: :strict)
  .eager_load(:line_items) {
    eager_load(:product, active_record_fallback: :strict)
  }
  .run
```

---

# Unsupported features

The following ActiveRecord features are under consideration, but not high priority. Pull requests welcome!

* Eager loading `through` associations that involve a `has_and_belongs_to_many`.

The following ActiveRecord features are not supported, and likely never will be. Pull requests are still welcome, though.

* Eager loading `through` associations that involve a polymorphic association.
* ActiveRecord enum types
* ActiveRecord serialized types

---

# Benchmarking

`bundle exec rake bench` will run a suite of speed and memory benchmarks comparing Occams Record to Active Record. [You can find an example of a typical run here.](https://github.com/jhollinger/occams-record/wiki/Measurements) These are primarily used during development to prevent performance regressions. An in-memory Sqlite database is used.

If you run your own benchmarks, keep in mind exactly what you're measuring. For example if you're benchmarking a report written in AR vs OR, there are many constants in that measurement: the time spent in the database, the time spent sending the database results over the network, any calculations you're doing in Ruby, and the time spent building your html/json/csv/etc. So if OR is 3x faster than AR, the total runtime of said report *won't* improve by 3x.

On the other hand, Active Record makes it *very* easy to forget to eager load associations (the N+1 query problem). Occams Record fixes that. So if your report was missing some associations you could see easily see performance improvements well over 3x.

# Testing

```bash
bundle install

# test against SQLite
bundle exec rake test

# test against Postgres
TEST_DATABASE_URL=postgresql://postgres@localhost:5432/occams_record bundle exec rake test

# test against MySQL
TEST_DATABASE_URL=mysql2://root:@127.0.0.1:3306/occams_record bundle exec rake test
```

**Test against all supported ActiveRecord versions**

```bash
bundle exec appraisal install

# test against all supported AR versions (defaults to SQLite)
bundle exec appraisal rake test

# test against a specific AR version
bundle exec appraisal ar-7.0 rake test

# test against Postgres
TEST_DATABASE_URL=postgresql://postgres@localhost:5432/occams_record bundle exec appraisal rake test
```

# License

MIT License. See LICENSE for details.

# Copyright

Copywrite (c) 2019 Jordan Hollinger.
