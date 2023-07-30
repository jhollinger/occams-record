# Instance Methods

OccamsRecords results are just plain structs; they don't have methods from your Rails models. (Separating your persistence layer from your domain is good thing!) But sometimes you need a few methods. OccamsRecord provides two ways of accomplishing this.

## Injecting modules

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

orders = OccamsRecord.
  query(Order.all, use: MyOrderMethods).
  eager_load(:line_items) {
    eager_load(:product, use: [MyProductMethods, OtherMethods])
  }.
  find_each { |order|
    puts order.description # MyOrderMethods#description
    puts order.line_items[0].product.expensive? # MyProductMethods#expensive?
  }
```

## ActiveRecord fallback mode

This is an ugly hack of last resort if you can’t easily extract a method from your model into a shared module. Plugins, like carrierwave, are a good example. When you call a method that doesn’t exist on an OccamsRecord result, it will initialize an ActiveRecord object and forward the method call to it.

The `active_record_fallback` option must be passed either `:lazy` or `:strict` (recommended). `:strict` enables ActiveRecord’s strict loading option, helping you avoid N+1 queries in your model code. `:lazy` allows them. (`:strict` is only available for ActiveRecord 6.1 and later.)

The following will forward any nonexistent methods for `Order` and `Product` records:

```ruby
orders = OccamsRecord.
  query(Order.all, active_record_fallback: :strict).
  eager_load(:line_items) {
    eager_load(:product, active_record_fallback: :strict)
  }.
  run
```
