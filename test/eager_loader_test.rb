require 'test_helper'

class EagerLoaderTest < Minitest::Test
  def test_belongs_to_query
    ref = Widget.reflections.fetch 'category'
    loader = MicroRecord::EagerLoaders::BelongsTo.new(ref, ->(q) { q.where(name: 'Foo') })
    widgets = [
      OpenStruct.new(category_id: 5),
      OpenStruct.new(category_id: 10),
    ]
    sql = loader.query(widgets).to_sql
    assert_equal %q(SELECT "categories".* FROM "categories" WHERE "categories"."name" = 'Foo' AND "categories"."id" IN (5, 10)), sql
  end

  def test_belongs_to_merge
    ref = Widget.reflections.fetch 'category'
    loader = MicroRecord::EagerLoaders::BelongsTo.new(ref)
    widgets = [
      OpenStruct.new(id: 1, name: "A", category_id: 5),
      OpenStruct.new(id: 2, name: "B", category_id: 10),
    ]

    loader.merge!([
      OpenStruct.new(id: 5, name: "Cat A"),
      OpenStruct.new(id: 10, name: "Cat B"),
    ], widgets)

    assert_equal [
      OpenStruct.new(id: 1, name: "A", category_id: 5, category: OpenStruct.new(id: 5, name: "Cat A")),
      OpenStruct.new(id: 2, name: "B", category_id: 10, category: OpenStruct.new(id: 10, name: "Cat B")),
    ], widgets
  end

  def test_has_one_query
    ref = Widget.reflections.fetch 'detail'
    loader = MicroRecord::EagerLoaders::HasOne.new(ref)
    widgets = [
      OpenStruct.new(id: 1),
      OpenStruct.new(id: 52),
    ]
    sql = loader.query(widgets).to_sql
    assert_equal %q(SELECT "widget_details".* FROM "widget_details" WHERE "widget_details"."widget_id" IN (1, 52)), sql
  end

  def test_has_one_merge
    ref = Widget.reflections.fetch 'detail'
    loader = MicroRecord::EagerLoaders::HasOne.new(ref)
    widgets = [
      OpenStruct.new(id: 1, name: "A"),
      OpenStruct.new(id: 2, name: "B"),
    ]

    loader.merge!([
      OpenStruct.new(id: 5, widget_id: 1, text: "Detail A"),
      OpenStruct.new(id: 10, widget_id: 2, text: "Detail B"),
    ], widgets)

    assert_equal [
      OpenStruct.new(id: 1, name: "A", detail: OpenStruct.new(id: 5, widget_id: 1, text: "Detail A")),
      OpenStruct.new(id: 2, name: "B", detail: OpenStruct.new(id: 10, widget_id: 2, text: "Detail B")),
    ], widgets
  end

  def test_has_many_query
    ref = Order.reflections.fetch 'items'
    loader = MicroRecord::EagerLoaders::HasMany.new(ref)
    orders = [
      OpenStruct.new(id: 1000),
      OpenStruct.new(id: 1001),
    ]
    sql = loader.query(orders).to_sql
    assert_equal %q(SELECT "order_items".* FROM "order_items" WHERE "order_items"."order_id" IN (1000, 1001)), sql
  end

  def test_has_many_merge
    ref = Order.reflections.fetch 'items'
    loader = MicroRecord::EagerLoaders::HasMany.new(ref)
    orders = [
      OpenStruct.new(id: 1000),
      OpenStruct.new(id: 1001),
      OpenStruct.new(id: 1002),
    ]

    loader.merge!([
      OpenStruct.new(id: 5000, order_id: 1000),
      OpenStruct.new(id: 5001, order_id: 1000),
      OpenStruct.new(id: 5003, order_id: 1000),
      OpenStruct.new(id: 6000, order_id: 1001),
      OpenStruct.new(id: 6001, order_id: 1001),
      OpenStruct.new(id: 7000, order_id: 9),
    ], orders)

    assert_equal [
      OpenStruct.new(id: 1000, items: [
        OpenStruct.new(id: 5000, order_id: 1000),
        OpenStruct.new(id: 5001, order_id: 1000),
        OpenStruct.new(id: 5003, order_id: 1000),
      ]),
      OpenStruct.new(id: 1001, items: [
        OpenStruct.new(id: 6000, order_id: 1001),
        OpenStruct.new(id: 6001, order_id: 1001),
      ]),
      OpenStruct.new(id: 1002, items: []),
    ], orders
  end
end
