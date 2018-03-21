# Occam's Record [![Build Status](https://travis-ci.org/jhollinger/occams-record.svg?branch=master)](https://travis-ci.org/jhollinger/occams-record)

> Do not multiply entities beyond necessity. -- Occam's Razor

Occam's Record is a high-efficiency, advanced query library for ActiveRecord apps. It is **not** an ORM or an ActiveRecord replacement. Use it to solve pain points in your existing ActiveRecord app.

* 3x-5x faster than ActiveRecord queries.
* Uses 1/3 the memory of ActiveRecord query results.
* Eliminates the N+1 query problem.
* Allows custom SQL when eager loading associations (use `select`, `where`, `order`, etc).
* `find_each`/`find_in_batches` respects `order` and `limit`.
* Allows eager loading of associations when querying with raw SQL.
* Allows `find_each`/`find_in_batches` when querying with raw SQL.
* Eager load data from arbitrary SQL (no association required).

[Look over the speed and memory measurements yourself!](https://github.com/jhollinger/occams-record/wiki/Measurements) OccamsRecord achieves all of this by making some very specific trade-offs:

* OccamsRecord results are **read-only**.
* OccamsRecord results are **purely database rows** - they don't have any instance methods from your Rails models.
* OccamsRecord queries must eager load each association that will be used. Otherwise they simply won't be availble.

## Usage

Full documentation is available at [rubydoc.info/gems/occams-record](http://www.rubydoc.info/gems/occams-record).

**Add to your Gemfile**

```ruby
gem 'occams-record'
```

**Simple example**

```ruby
widgets = OccamsRecord.
  query(Widget.order("name")).
  eager_load(:category).
  run

widgets[0].id
=> 1000

widgets[0].name
=> "Widget 1000"

widgets[0].category.name
=> "Category 1"
```

**More complicated example**

Notice that we're eager loading splines, but *only the fields that we need*. If that's a wide table, your DBA will thank you.

```ruby
widgets = OccamsRecord.
  query(Widget.order("name")).
  eager_load(:category).
  eager_load(:splines, select: "widget_id, description").
  run

widgets[0].splines.map { |s| s.description }
=> ["Spline 1", "Spline 2", "Spline 3"]

widgets[1].splines.map { |s| s.description }
=> ["Spline 4", "Spline 5"]
```

**An insane example, but only half as insane as the one that prompted the creation of this library**

Here we're eager loading several levels down. Notice the `Proc` given to `eager_load(:orders)`. The `select:` option is just for convenience; you may instead pass a `Proc` and customize the query with any of ActiveRecord's query builder helpers (`select`, `where`, `order`, `limit`, etc).

```ruby
widgets = OccamsRecord.
  query(Widget.order("name")).
  eager_load(:category).

  # load order_items, but only the fields needed to identify which orders go with which widgets
  eager_load(:order_items, select: "widget_id, order_id") {

    # load the orders ("q" has all the normal query methods and any scopes defined on Order)
    eager_load(:orders, ->(q) { q.select("id, customer_id").order("order_date DESC") }) {

      # load the customers who made the orders, but only their names
      eager_load(:customer, select: "id, name")
    }
  }.
  run
```

**Eager load using raw SQL without a predefined association**

Let's say we want to load each widget and eager load all the customers who've ever ordered it. We could do that using the above example, but we end up loading a lot of useless intermediate records. What if we could define an ad hoc association, using raw SQL, to load exactly what we need? Enter `eager_load_one` and `eager_load_many`! See the full documentation for a full description of all options.

```ruby
widgets = OccamsRecord.
  query(Widget.order("name")).

  # load the results of the query into "customers", matching "widget_id"
  # in the results to the "id" field of the widgets
  eager_load_many(:customers, {:widget_id => :id}, %(
    SELECT DISTINCT customers.id, customers.name, order_items.widget_id
    FROM customers
      INNER JOIN orders ON orders.customer_id = customers.id
      INNER JOIN order_items ON order_items.order_id = orders.id
    WHERE order_items.widget_id IN (%{ids})
  ), binds: {
    # additional bind values (ids will be passed in for you)
  }).
  run
```

## Injecting instance methods

By default your results will only have getters for selected columns and eager-loaded associations. If you must, you *can* inject extra methods into your results by putting those methods into a Module. NOTE this is discouraged, as you should try to maintain a clear separation between your persistence layer and your domain.

```ruby
module MyWidgetMethods
  def to_s
    name
  end

  def expensive?
    price_per_unit > 100
  end
end

module MyOrderMethods
  def description
    "#{order_number} - #{date}"
  end
end

widgets = OccamsRecord.
  query(Widget.order("name"), use: MyWidgetMethods).
  eager_load(:orders, use: [MyOrderMethods, SomeAdditionalMethods]).
  run

widgets[0].to_s
=> "Widget A"

widgets[0].price_per_unit
=> 57.23

widgets[0].expensive?
=> false

widgets[0].orders[0].description
=> "O839SJZ98B - 1/8/2017"
```

## Raw SQL queries

If you have a complicated query to run, you may drop down to hand-written SQL while still taking advantage of eager loading and variable escaping (not possible in ActiveRecord). Note the slightly different syntax for binding variables.

NOTE this feature is quite new and might have some bugs. Since we are not yet at 1.0, breaking changes may occur. Issues and Pull Requests welcome.

```ruby
widgets = OccamsRecord.sql(%(
  SELECT * FROM widgets
  WHERE category_id = %{cat_id}
), {
  cat_id: 5
}).run
```

**Performing eager loading with raw SQL**

To perform eager loading with raw SQL you must specify the base model. NOTE some database adapters, notably SQLite, require you to always specify the model.

```ruby
widgets = OccamsRecord.
  sql(%(
    SELECT * FROM widgets
    WHERE category_id IN (%{cat_ids})
  ), {
    cat_ids: [5, 10]
  }).
  model(Widget).
  eager_load(:category).
  run
```

**Using find_each/find_in_batches with raw SQL**

To use `find_each` or `find_in_batches` with raw SQL you must provide the `LIMIT` and `OFFSET` clauses yourself. The bind values for these will be filled in by OccamsRecord. Remember to always specific a consitent `ORDER BY` clause.

```ruby
widgets = OccamsRecord.sql(%(
  SELECT * FROM widgets
  WHERE category_id = %{cat_id}
  ORDER BY name, id
  LIMIT %{batch_limit}
  OFFSET %{batch_offset}
), {
  cat_id: 5
}).find_each { |widget|
  puts widget.name
}
```

## Unsupported features

The following `ActiveRecord` are not supported, and I have no plans to do so. However, I'd be glad to accept pull requests.

* ActiveRecord enum types
* ActiveRecord serialized types

## Testing

To run the tests, simply run:

```bash
bundle install
bundle exec rake test
```

By default, bundler will install the latest (supported) version of ActiveRecord. To specify a version to test against, run:

```bash
AR=4.2 bundle update activerecord
bundle exec rake test
```

Look inside `Gemfile` to see all testable versions.
