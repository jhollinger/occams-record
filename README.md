### Occams Record ![Build Status](https://travis-ci.org/jhollinger/occams-record.svg?branch=master)](https://travis-ci.org/jhollinger/occams-record)

> Do not multiply entities beyond necessity. -- Occam's Razor

Occam's Record is a high-efficiency, advanced query library for ActiveRecord apps. It is **not** an ORM or an ActiveRecord replacement. Use it to solve pain points in your existing ActiveRecord app. Occams Record gives you two things:

**Performance**

* 3x-5x faster than ActiveRecord queries.
* Uses 1/3 the memory of ActiveRecord query results.
* Eliminates the N+1 query problem.

**Powerful eager loading**

* Customize your SQL when eager loading associations.
* Use `ORDER BY` with `find_each`/`find_in_batches`.
* Use `find_each`/`find_in_batches` with raw SQL queries.
* Eager load when quering with raw SQL.
* Use raw SQL to eager load into an ad hoc association.

[Look over the speed and memory measurements yourself!](https://github.com/jhollinger/occams-record/wiki/Measurements) OccamsRecord achieves all of this by making some very specific trade-offs:

* OccamsRecord results are *read-only*.
* OccamsRecord results are *purely database rows* - they don't have any instance methods from your Rails models.
* You *must eager load* each assocation you intend to use. If you forget one, an exception will be raised.

---

# Installation

Simply add it to your `Gemfile`:

```ruby
gem 'occams-record'
```

---

# Overview

Full documentation is available at [rubydoc.info/gems/occams-record](http://www.rubydoc.info/gems/occams-record).

Build your queries like normal, using ActiveRecord's excellent query builder. Then pass them off to Occams Record.

```ruby
q = Order.
  completed.
  where("order_date > ?", 30.days.ago).
  order("order_date DESC")

orders = OccamsRecord.
  query(q).
  run
````

`each`, `map`, `reduce`, and other Enumerable methods may be used instead of *run*. `find_each` and `find_in_batches` are also supported. Unlike their ActiveRecord counterparts they respect *ORDER BY*. Occams Record has great support for raw SQL queries too, but we'll get to those later.

## Basic eager loading

Eager loading is similiar to ActiveRecord's `preload` (each association is loaded in a separate query). Nested associations use blocks instead of Hashes. And if you try to use an association you didn't eager load an exception will be raised.

```ruby
orders = OccamsRecord.
  query(q).
  eager_load(:customer).
  eager_load(:line_items) {
    eager_load(:product)
  }.
  run
  
order = orders[0]
puts order.customer.name

order.line_items.each { |line_item|
  puts line_item.product.name
  puts line_item.product.category.name
  OccamsRecord::MissingEagerLoadError: Association 'category' is unavailable on Product because it was not eager loaded!
}
```

## Advanced eager loading

Occams Record allows you to customize each eager load query using the full power of ActiveRecord's query builder.

```ruby
orders = OccamsRecord.
  query(q).
  # Only SELECT these two columns. Your DBA will thank you, esp. on "wide" tables.
  eager_load(:customer, select: "id, name").
  
  # A Proc can customize the query using any of ActiveRecord's query builders and
  # any scopes you've defined on the LineItem model.
  eager_load(:line_items, ->(q) { q.active.order("created_at") }) {
    eager_load(:product)
  }.
  run
```

Occams Record also supports creating ad hoc associations using raw SQL. We'll get to that in the next section.

## Raw SQL queries

ActiveRecord has raw SQL "escape hatches" like `find_by_sql` or `exec_query`, but they both give up critical features like eager loading and `find_each`/`find_in_batches`. Not so with Occams Record!

**Batched loading**

To use `find_each`/`find_in_batches` you must provide the limit and offset statements yourself. OccamsRecord will fill in the values for you. Also, notice that the binding syntax is a bit different (it uses Ruby's built-in named string substitution).

```ruby
OccamsRecord.
  sql(%(
    SELECT * FROM orders
    WHERE order_date > %{date}
    ORDER BY order_date DESC
    LIMIT %{batch_limit}
    OFFSET %{batch_offset}
  ), {
    date: 30.days.ago
  }).
  find_each(batch_size: 1000) do |order|
    ...
  end
```

**Eager loading**

To use `eager_load` with a raw SQL query you must tell Occams what the base model is. (That doesn't apply if you're loading an ad hoc, raw SQL association. We'll get to those later).

```ruby
orders = OccamsRecord.
  sql(%(
    SELECT * FROM orders
    WHERE order_date > %{date}
    ORDER BY order_date DESC
  ), {
    date: 30.days.ago
  }).
  model(Order).
  eager_load(:customer).
  run
```

## Raw SQL eager loading

Let's say we want to load each product with an array of all customers who've ordered it. We *could* do that by loading various nested associations:

```ruby
products_with_orders = OccamsRecord.
  query(Product.all).
  eager_load(:line_items) {
    eager_load(:order) {
      eager_load(:customer)
    }
  }.
  map { |product|
    customers = product.line_items.map(&:order).map(&:customer).uniq
    [product, customers]
  }
```

But that's very wasteful. Occams gives us a better options: `eager_load_many` and `eager_load_one`.

```ruby
products = OccamsRecord.
  query(Product.all).
  eager_load_many(:customers, {:product_id => :id}, %w(
    SELECT DISTINCT product_id, customers.*
    FROM line_items
      INNER JOIN orders ON line_items.order_id = orders.id
      INNER JOIN customers on orders.customer_id = customers.id
    WHERE line_items.product_id IN (%{ids})
  ), binds: {
    # additional bind values (ids will be passed in for you)
  }).
  run
```

`eager_load_many` allows us to declare an ad hoc *has_many* association called *customers*. The `{:product_id => :id}` Hash defines the mapping: *product_id* in these results maps to *id* in the parent Product. The SQL string and binds should be familiar by now. The `%{ids}` value will be provided for you - just stick it in the right place.

`eager_load_one` defines an ad hoc `has_one`/`belongs_to` association.

These ad hoc eager loaders are available on both `OccamsRecord.query` and `OccamsRecord.sql`. While eager loading with `OccamsRecord.sql` normallly requires you to declare the model, that is not necessary with `eager_load_one`/`eager_load_many`.

## Injecting instance methods

Occams Records results are just plain rows; there are no methods from your Rails models. (Separating your persistence layer from your domain is good thing!) But sometimes you need a few methods. Occams Record allows you to specify modules to be included in your results.

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

orders = OccamsRecord.
  query(Order.all, use: MyOrderMethods).
  eager_load(:line_items) {
    eager_load(:product, use: [MyProductMethods, OtherMethods])
  }.
  run
```

---

# Unsupported features

The following ActiveRecord features are under consideration, but not high priority. Pull requests welcome!

* `:through` associations.

The following ActiveRecord features are not supported, and likely never will be. Pull requests are still welcome, though.

* ActiveRecord enum types
* ActiveRecord serialized types

---

# Testing

To run the tests, simply run:

```bash
bundle install
bundle exec rake test
```

By default, bundler will install the latest (supported) version of ActiveRecord. To specify a version to test against, run:

```bash
AR=5.2 bundle update activerecord
bundle exec rake test
```

Look inside `Gemfile` to see all testable versions.
