require 'test_helper'

class EagerLoadingPolymorphicTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_polymorphic_belongs_to_query
    ref = LineItem.reflections.fetch 'item'
    loader = OccamsRecord::EagerLoaders::PolymorphicBelongsTo.new(ref)
    line_items = [
      OpenStruct.new(item_id: 5, item_type: 'Widget'),
      OpenStruct.new(item_id: 6, item_type: 'Widget'),
      OpenStruct.new(item_id: 10, item_type: 'Spline'),
      OpenStruct.new(item_id: 11, item_type: 'Spline'),
    ]
    sqlz = []
    loader.send(:query, line_items) { |scope| sqlz << scope.to_sql }
    assert_equal [
      %q(SELECT splines.* FROM splines WHERE splines.id IN (10, 11)),
      %q(SELECT widgets.* FROM widgets WHERE widgets.id IN (5, 6)),
    ].sort, sqlz.sort.map { |x|
      normalize_sql x
    }
  end

  def test_polymorphic_belongs_to_merge
    ref = LineItem.reflections.fetch 'item'
    loader = OccamsRecord::EagerLoaders::PolymorphicBelongsTo.new(ref)
    widget_result = OccamsRecord::Results.klass(%w(id name), {}, [], model: Widget)
    widget_a = widget_result.new(['5', 'Widget A'])
    widget_b = widget_result.new(['6', 'Widget B'])

    spline_result = OccamsRecord::Results.klass(%w(id name), {}, [], model: Spline)
    spline_a = spline_result.new(['10', 'Spline A'])

    line_items = [
      OpenStruct.new(item_id: widget_a.id, item_type: 'Widget'),
      OpenStruct.new(item_id: widget_b.id, item_type: 'Widget'),
      OpenStruct.new(item_id: spline_a.id, item_type: 'Spline'),
      OpenStruct.new(item_id: 11, item_type: 'Spline'),
    ]

    # Merge in widgets
    loader.send(:merge!, [
      widget_a,
      widget_b,
      widget_result.new(['7', 'Widget C']),
    ], line_items)
    assert_equal [
      OpenStruct.new(item_id: widget_a.id, item_type: 'Widget', item: widget_a),
      OpenStruct.new(item_id: widget_b.id, item_type: 'Widget', item: widget_b),
      OpenStruct.new(item_id: spline_a.id, item_type: 'Spline'),
      OpenStruct.new(item_id: 11, item_type: 'Spline'),
    ], line_items

    # Merge in nothing (simulate that none of the referenced Splines actually exist)
    loader.send(:merge!, [], line_items)
    assert_equal [
      OpenStruct.new(item_id: widget_a.id, item_type: 'Widget', item: widget_a),
      OpenStruct.new(item_id: widget_b.id, item_type: 'Widget', item: widget_b),
      OpenStruct.new(item_id: spline_a.id, item_type: 'Spline'),
      OpenStruct.new(item_id: 11, item_type: 'Spline'),
    ], line_items

    # Now merge in one of the Splines, but pretend the other doesn't exist
    loader.send(:merge!, [spline_a], line_items)
    assert_equal [
      OpenStruct.new(item_id: widget_a.id, item_type: 'Widget', item: widget_a),
      OpenStruct.new(item_id: widget_b.id, item_type: 'Widget', item: widget_b),
      OpenStruct.new(item_id: spline_a.id, item_type: 'Spline', item: spline_a),
      OpenStruct.new(item_id: 11, item_type: 'Spline', item: nil),
    ], line_items
  end

  def test_eager_load_nested_under_polymorphic
    line_items = OccamsRecord.
      query(LineItem.order(:amount)).
      eager_load(:item) {
        eager_load(:category)
        eager_load(:detail) # Widgets only
      }.
      run

      assert_equal [
        "Spline C (Bar) - N/A",
        "Widget A (Foo) - All about Widget A",
        "Spline A (Foo) - N/A",
        "Widget C (Foo) - All about Widget C",
        "Widget D (Bar) - All about Widget D",
      ], line_items.map { |x|
        details = x.item.respond_to?(:detail) ? x.item.detail.text : "N/A"
        "#{x.item.name} (#{x.item.category.name}) - #{details}"
      }
  end

  def test_nested_with_poly_belongs_to
    log = []
    results = OccamsRecord.
      query(Order.all, query_logger: log).
      eager_load(:customer).
      eager_load(:line_items) {
        eager_load(:item)
      }.
      run

    assert_equal [
      %q(root: SELECT orders.* FROM orders),
      %q(root.customer: SELECT customers.* FROM customers WHERE customers.id IN (846114006, 980204181)),
      %q(root.line_items: SELECT line_items.* FROM line_items WHERE line_items.order_id IN (683130438, 834596858)),
      %q(root.line_items.item: SELECT widgets.* FROM widgets WHERE widgets.id IN (112844655, 417155790, 683130438)),
      %q(root.line_items.item: SELECT splines.* FROM splines WHERE splines.id IN (112844655, 683130438)),
    ], log.map { |x|
      normalize_sql x
    }

    assert_equal Order.all.map { |o|
      {
        id: o.id,
        date: o.date,
        amount: o.amount,
        customer_id: o.customer_id,
        customer: {
          id: o.customer.id,
          name: o.customer.name
        },
        line_items: o.line_items.map { |i|
          {
            id: i.id,
            order_id: i.order_id,
            item_id: i.item_id,
            item_type: i.item_type,
            category_id: i.item.category_id,
            amount: i.amount,
            item: {
              id: i.item.id,
              name: i.item.name,
              category_id: i.item.category_id
            }
          }
        }
      }
    }, results.map { |r| r.to_hash(symbolize_names: true, recursive: true) }
  end

  def test_poly_has_many
    results = OccamsRecord.
      query(Widget.all).
      eager_load(:line_items).
      run

    assert_equal Widget.count, results.size
    results.each do |widget|
      count = LineItem.where(item_id: widget.id, item_type: 'Widget').count
      assert_equal count, widget.line_items.size
      assert_equal count, widget.line_item_ids.size
    end
  end
end
