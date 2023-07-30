# Hand-written SQL

*Docs:* [sql](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2Esql)

Sometimes you have to write a big, gnarly SQL query by hand. Here's a basic example (using simple SQL for brevity):

```ruby
OccamsRecord.
  sql("
    SELECT * FROM orders
    WHERE order_date > :date
    ORDER BY order_date DESC, id
  ", {
    date: 30.days.ago
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
