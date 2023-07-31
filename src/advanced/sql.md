# Hand-written SQL

*Docs:* [sql](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2Esql)

Sometimes you have to write a big, gnarly SQL query by hand. Here's an example using Common Table Expressions (CTE).

```ruby
OccamsRecord.
  sql("
    WITH regional_sales AS (
      SELECT region, SUM(amount) AS total_sales
      FROM orders
      GROUP BY region
    ), top_regions AS (
      SELECT region
      FROM regional_sales
      WHERE total_sales > :min_sales
    )
    SELECT
      region,
      product,
      SUM(quantity) AS product_units,
      SUM(amount) AS product_sales
    FROM orders
    WHERE region IN (:regions)
    GROUP BY region, product;
  ", {
    min_sales: 10_000,
    regions: ["A", "B", "C"],
  }).
  each { |order|
     ...
  }
```

OccamsRecord supports several query param syntaxes:

```ruby
# Rails-style
OccamsRecord.sql("SELECT ... WHERE orders.date > :date", {date: date})
OccamsRecord.sql("SELECT ... WHERE orders.date > ?", [date])

# Ruby-style
OccamsRecord.sql("SELECT ... WHERE orders.date > %{date}", {date: date})
OccamsRecord.sql("SELECT ... WHERE orders.date > %s", [date])
```
