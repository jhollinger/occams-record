# Occam's Record [![Build Status](https://travis-ci.org/jhollinger/occams-record.svg?branch=master)](https://travis-ci.org/jhollinger/occams-record)

> Do not multiply entities beyond necessity. -- Occam's Razor

Occam's Record is a high-efficiency query API for ActiveRecord. It is 3x-5x faster, uses 1/3 of the memory, eliminates the N+1 query problem, and allows for much more flexible eager loading. OccamsRecord achieves this by making some very specific trade-offs:

* OccamsRecord results are **read-only**.
* OccamsRecord objects are **purely database rows** - they don't have any instance methods from your Rails models.
* OccamsRecord queries must specify each association that will be used. Otherwise they simply won't be availble.

OccamsRecord is **not** an ORM or an ActiveRecord replacement. Use it to solve pain points in your existing ActiveRecord app. For more on the rational behind OccamsRecord, see the Rational section at the end of the README.

**BREAKING CHANGE** to `eager_load` in version **0.10.0**. See the examples below or [HISTORY.md](https://github.com/jhollinger/occams-record/blob/v0.10.0/HISTORY.md) for the new usage.

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

NOTE this feature is quite new and might have some bugs. Issues and Pull Requests welcome.

```ruby
widgets = OccamsRecord.sql(%(
  SELECT * FROM widgets
  WHERE category_id = %{cat_id}
), {
  cat_id: 5
}).run
```

To perform eager loading, you must specify the base model. NOTE some database adapters, notably SQLite, require you to always specify the model.

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

## Rational

**What does OccamsRecord buy you?**

* OccamsRecord results are **one-third the size** of ActiveRecord results.
* OccamsRecord queries run **three to five times faster** than ActiveRecord queries.
* When eager loading associations you may specify which columns to `SELECT`. (This can be a significant performance boost to both your database and Rails app, on top of the above numbers.)
* When eager loading associations you may completely customize the query (`WHERE`, `ORDER BY`, `LIMIT`, etc.)
* By forcing eager loading of associations, OccamsRecord bypasses the primary cause of performance problems in Rails: N+1 queries.
* Forced eager loading also makes you consider the "shape" of your data, which can help you identify areas that need refactored (e.g. add redundant foreign keys, more denormalization, etc.)

**What don't you give up?**

* You can still write your queries using ActiveRecord's query builder, as well as your existing models' associations & scopes.
* You can still use ActiveRecord for everything else - small queries, creating, updating, and deleting records.
* You can still inject some instance methods into your results, if you must. See below.

**Is there evidence to back any of this up?**

Glad you asked. [Look over the results yourself.](https://github.com/jhollinger/occams-record/wiki/Measurements)

**Why not use a different ORM?**

That's a great idea; check out [sequel](https://rubygems.org/gems/sequel) or [rom](https://rubygems.org/gems/rom)! But for large, legacy codebases heavily invested in ActiveRecord, switching ORMs usually isn't practical. OccamsRecord can help you get some of those wins without a rewrite.

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
