# Occam's Record [![Build Status](https://travis-ci.org/jhollinger/occams-record.svg?branch=master)](https://travis-ci.org/jhollinger/occams-record)

> Do not multiply entities beyond necessity. -- Occam's Razor

EXPERIMENTAL. Occam's Record is a high-efficiency API for querying large sets with ActiveRecord. When loading thousands of records, ActiveRecord wastes a lot of RAM and CPU cycles on *things you'll never use.* Additionally, eagerly-loaded associations are forced to load each and every column, even if you only need a few.

For those stuck with ActiveRecord, OccamsRecord seeks to solve these issues by making some very specific trade-offs:

* OccamsRecord results are **read-only**.
* OccamsRecord objects are **purely database rows** - they don't have any instance methods from your Rails models.

**What does this buy you?**

* OccamsRecord results are **one-third the size** of ActiveRecord results.
* OccamsRecord queries run **three times faster** than ActiveRecord queries, or more.
* When you're eager loading associations you may specify which columns to `SELECT`. (This can be a significant performance boost to both your database and Rails app, on top of the above numbers.)

**What don't you give up?**

* You can still write your queries using ActiveRecord's query builder, as well as your existing models' associations & scopes.
* You can still use ActiveRecord for everything else - small queries, creating, updating, and deleting records.
* You can still inject some instance methods into your results, if you must. See below.

**Is there evidence to back any of this up?**

Glad you asked. [Look over the results yourself.](https://github.com/jhollinger/occams-record/wiki/Measurements)

## Usage

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
  eager_load(:splines, -> { select("widget_id, description") }).
  run

widgets[0].splines.map { |s| s.description }
=> ["Spline 1", "Spline 2", "Spline 3"]

widgets[1].splines.map { |s| s.description }
=> ["Spline 4", "Spline 5"]
```

**An insane example, but only half as insane as the one that prompted the creation of this library**

In addition to custom eager loading queries, we're also adding nested eager loading (and customizing those queries!).

```ruby
widgets = OccamsRecord.
  query(Widget.order("name")).
  eager_load(:category).

  # load order_items, but only the fields needed to identify which orders go with which widgets
  eager_load(:order_items, -> { select("widget_id, order_id") }) {

    # load the orders
    eager_load(:orders) {

      # load the customers who made the orders, but only their names
      eager_load(:customer, -> { select("id, name") })
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
  eager_load(:orders, use: MyOrderMethods).
  run

widgets[0].to_s
=> "Widget A"

widgets[0].price_per_unit
=> 57.23

widgets[0].expensive?
=> false

widgets[0].orders[0].description
=> "O839SJZ98B 1/8/2017"
```

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
