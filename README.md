# micro-record (teeny-record?)

EXPERIMENTAL. A low-memory interface for running large ActiveRecord queries.

When pulling back very large sets of data, ActiveRecord can only take you so far, even when using `eager_load`, `find_each`, `find_in_batches`, and friends. Those tools make ActiveRecord almsot fast enough to be tolerable, but at the cost of severe memory bloat (hundreds of MBs to several GB). The main causes are:
* ActiveRecord objects are big. Really big. You just won't believe how vastly, hugely, mind-bogglingly big they are.
* When you're eager loading lots of associations, you're likely pulling back far more columns than you actually need.

`MicroRecord` tries to solve those two problems. Your records come back as (relatively) tiny `OpenStruct` objects, and you can easily customize your eager loading queries (limit the `SELECT` fields, add a `WHERE` clause, etc.). The best part is that you can still use ActiveRecord's query build and all the scopes you've defined on your models.

**Simple example**

Here's a very simple example. So simple that there's really no reason to use `MicroRecord` with it.

    results = MicroRecord.
      query(Widget.order("name")).
      eager_load(:category).
      run

    results[0].class.name
    => "OpenStruct"

    results[0].id
    => 1000

    results[0].name
    => Widget 1000

    results[0].category.name
    => "Category 1"

**More complicated example**

Notice that we're eager loading splines, but *only the fields that we need*.

    results = MicroRecord.
      query(Widget.order("name")).
      eager_load(:category).
      eager_load(:splines, ->(q) { q.select("widget_id, description") }).
      run

    results[0].splines.map { |s| s.description }
    => ["Spline 1", "Spline 2", "Spline 3"]

    results[1].splines.map { |s| s.description }
    => ["Spline 4", "Spline 5"]

    [#<Date: 2017-01-01>, #<Date: 2017-01-02>, #<Date: 2017-01-03>, ...]

**An insane example, but only half as insane as the one that prompted the creation of this library**

In addition to custom eager loading queries, we're also adding nested eager loading (and customizing those queries!).

    results = MicroRecord.
      query(Widget.order("name")).
      eager_load(:category).

      # load order_items, but only the fields we need identify which orders go with which widget
      eager_load(:order_items, ->(q) { q.select("widget_id, order_id") }) {

        # load the orders
        eager_load(:orders) {

          # load the customer who made the order, but only their name
          eager_load(:customer, ->(q) { q.select("name") })
        }
      }.
      run

## TODO

* Support `has_and_belongs_to_many` associations
* PostgreSQL: correctly handle double quotes inside hstore keys and values.
* PostgreSQL: correctly handle commas in array string values.
