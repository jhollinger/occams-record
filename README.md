# micro-record

EXPERIMENTAL. A low-memory interface for running large ActiveRecord queries.

When pulling back very large sets of data in ActiveRecord, `preload` and `find_each` are the go-to tools. But when you need to eager load more than a few associations (especially a few `has_many`'s), these tools start to break down. (More associations = more memory usage per batch = smaller batches = more batches = more time.) MicroRecord seeks to solve these issues by making some very specific trade-offs:
* MicroRecord results are roughly one-thid the size of ActiveRecord results.
* MicroRecord queries take rougly one-third the time of ActiveRecord queries.
* MicroRecord results are read-only.
* MicroRecord objects do not have any instance methods from your Rails models; they're purely database rows.
* You can still write your queries using ActiveRecord's query builder, as well as your existing models' scopes.
* When you're eager loading associations you may specify which columns to `SELECT`. (This can be a significant performance boost to both your database and Rails app, on top of the above numbers.)

**Simple example**

Here's a very simple example. So simple that there's no reason to use `MicroRecord` with it.

    widgets = MicroRecord.
      query(Widget.order("name")).
      eager_load(:category).
      run

    widgets[0].id
    => 1000

    widgets[0].name
    => "Widget 1000"

    widgets[0].category.name
    => "Category 1"

**More complicated example**

Notice that we're eager loading splines, but *only the fields that we need*. If that's a wide table, your DBA will thank you.

    widgets = MicroRecord.
      query(Widget.order("name")).
      eager_load(:category).
      eager_load(:splines, -> { select("widget_id, description") }).
      run

    widgets[0].splines.map { |s| s.description }
    => ["Spline 1", "Spline 2", "Spline 3"]

    widgets[1].splines.map { |s| s.description }
    => ["Spline 4", "Spline 5"]

**An insane example, but only half as insane as the one that prompted the creation of this library**

In addition to custom eager loading queries, we're also adding nested eager loading (and customizing those queries!).

    widgets = MicroRecord.
      query(Widget.order("name")).
      eager_load(:category).

      # load order_items, but only the fields needed to identify which orders go with which widgets
      eager_load(:order_items, -> { select("widget_id, order_id") }) {

        # load the orders
        eager_load(:orders) {

          # load the customers who made the orders, but only their names
          eager_load(:customer, -> { select("name") })
        }
      }.
      run

## TODO

* Support `has_and_belongs_to_many` associations
* Support something like `find_each`/`find_in_batches`
