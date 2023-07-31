# Ad Hoc Associations

*Docs:* [eager_load_many](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FEagerLoaders%2FBuilder:eager_load_many), [eager_load_one](https://www.rubydoc.info/gems/occams-record/OccamsRecord%2FEagerLoaders%2FBuilder:eager_load_one)

On rare occasions you may need to eager load an association *that doesn't actually exist in your models*. Maybe it's too convoluted to represent with ActiveRecord. Or maybe it's just deeply nested and you don't want to waste time/memory loading all the intermediate records.

### eager_load_many

The following example uses `eager_load_many` to load a non-existent, has-many association on `Product` called `customers`. Each product will have a `customers` attribute that contains the customers who bought the product.

```ruby
OccamsRecord.
  query(Product.all).
  eager_load_many(:customers, {:id => :product_id}, "
    SELECT DISTINCT product_id, customers.*
    FROM line_items
      INNER JOIN orders ON line_items.order_id = orders.id
      INNER JOIN customers on orders.customer_id = customers.id
    WHERE
      line_items.product_id IN (:ids)
      AND customers.created_at >= :date
  ", binds: {
    date: params[:date]
  })
```

That's a lot, so we'll break it down. The method call really just looks like this:

```ruby
eager_load_many(:customers, {:id => :product_id}, "SOME SQL", binds: {date: some_date})
```

The first argument, `:customers`, simply gives this made-up association a name. We'll call `product.customers` to get a product's customers.

The second argument, `{:id => :product_id}` defines the parent-child mapping. In this case it says, "The parent product records have an `id` field, and it will match the `product_id` field in the child customers."

The third argument is the SQL that loads customers. Notice the `line_items.product_id IN (:ids)` section. That's ensuring we're only loading customers that are related to the products we've loaded. OccamsRecord *will provide those ids for us* - don't worry. (And it's only called `:ids` because we defined the parent mapping as `:id`. If the parent mapping was instead `:code`, we'd put `:codes` in the SQL.)

The forth argument is optional. It can be a Hash or Array of any other query parameters you need.

### eager_load_one

`eager_load_one` works exactly the same but for one-to-one relationships.

### Nesting ad hoc associations

Like other eager loads, you can nest ad hoc ones. Here's an `eager_load_many` with an `eager_load_one` nested inside:

```ruby
OccamsRecord.
  query(Product.all).
  eager_load_many(:customers, {:id => :product_id}, "SELECT...") {
    eager_load_one(:something, {:id => :customer_id}, "SELECT...")
  }
```

Here's an `eager_load_many` with a **regular** `eager_load` nested!

```ruby
OccamsRecord.
  query(Product.all).
  eager_load_many(:customers, {:id => :product_id}, "SELECT...", model: Customer) {
    eager_load(:profile)
  }
```

Notice that we added `model: Customer` to `eager_load_many`'s arguments. That annotates the ad hoc association with the model, allowing us to use the regular `eager_load` on `Customer` associations like `:profile`.
