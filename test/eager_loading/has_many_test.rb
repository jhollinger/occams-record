require 'test_helper'

class EagerLoadingHasManyTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_has_many_query
    ref = Order.reflections.fetch 'line_items'
    loader = OccamsRecord::EagerLoaders::HasMany.new(ref)
    orders = [
      OpenStruct.new(id: 1000),
      OpenStruct.new(id: 1001),
    ]
    loader.send(:query, orders) { |scope|
      assert_equal %q(SELECT line_items.* FROM line_items WHERE line_items.order_id IN (1000, 1001)), normalize_sql(scope.to_sql)
    }
  end

  def test_has_many_merge
    ref = Order.reflections.fetch 'line_items'
    loader = OccamsRecord::EagerLoaders::HasMany.new(ref)
    orders = [
      OpenStruct.new(id: 1000),
      OpenStruct.new(id: 1001),
      OpenStruct.new(id: 1002),
    ]

    loader.send(:merge!, [
      OpenStruct.new(id: 5000, order_id: 1000),
      OpenStruct.new(id: 5001, order_id: 1000),
      OpenStruct.new(id: 5003, order_id: 1000),
      OpenStruct.new(id: 6000, order_id: 1001),
      OpenStruct.new(id: 6001, order_id: 1001),
      OpenStruct.new(id: 7000, order_id: 9),
    ], orders)

    assert_equal [
      OpenStruct.new(id: 1000, line_items: [
        OpenStruct.new(id: 5000, order_id: 1000),
        OpenStruct.new(id: 5001, order_id: 1000),
        OpenStruct.new(id: 5003, order_id: 1000),
      ]),
      OpenStruct.new(id: 1001, line_items: [
        OpenStruct.new(id: 6000, order_id: 1001),
        OpenStruct.new(id: 6001, order_id: 1001),
      ]),
      OpenStruct.new(id: 1002, line_items: []),
    ], orders
  end

  def test_has_many
    results = OccamsRecord.
      query(Order.all).
      eager_load(:line_items).
      run

    assert_equal Order.all.map { |o|
      {
        id: o.id,
        date: o.date,
        amount: o.amount,
        customer_id: o.customer_id,
        line_items: o.line_items.map { |i|
          {
            id: i.id,
            order_id: i.order_id,
            item_id: i.item_id,
            item_type: i.item_type,
            category_id: i.item.category_id,
            amount: i.amount
          }
        }
      }
    }, results.map { |r| r.to_hash(symbolize_names: true, recursive: true) }
  end
end
