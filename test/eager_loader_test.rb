require 'test_helper'

class EagerLoaderTest < Minitest::Test
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
      %q(SELECT "splines".* FROM "splines" WHERE "splines"."id" IN (10, 11)),
      %q(SELECT "widgets".* FROM "widgets" WHERE "widgets"."id" IN (5, 6)),
    ].sort, sqlz.sort
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

  def test_belongs_to_query
    ref = Widget.reflections.fetch 'category'
    loader = OccamsRecord::EagerLoaders::BelongsTo.new(ref, ->(q) { q.where(name: 'Foo') })
    widgets = [
      OpenStruct.new(category_id: 5),
      OpenStruct.new(category_id: 10),
    ]
    loader.send(:query, widgets) { |scope|
      assert_equal %q(SELECT "categories".* FROM "categories" WHERE "categories"."name" = 'Foo' AND "categories"."id" IN (5, 10)), scope.to_sql
    }
  end

  def test_belongs_to_merge
    ref = Widget.reflections.fetch 'category'
    loader = OccamsRecord::EagerLoaders::BelongsTo.new(ref)
    widgets = [
      OpenStruct.new(id: 1, name: "A", category_id: 5),
      OpenStruct.new(id: 2, name: "B", category_id: 10),
    ]

    loader.send(:merge!, [
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
    loader = OccamsRecord::EagerLoaders::HasOne.new(ref)
    widgets = [
      OpenStruct.new(id: 1),
      OpenStruct.new(id: 52),
    ]
    loader.send(:query, widgets) { |scope|
      assert_equal %q(SELECT "widget_details".* FROM "widget_details" WHERE "widget_details"."widget_id" IN (1, 52)), scope.to_sql
    }
  end

  def test_has_one_merge
    ref = Widget.reflections.fetch 'detail'
    loader = OccamsRecord::EagerLoaders::HasOne.new(ref)
    widgets = [
      OpenStruct.new(id: 1, name: "A"),
      OpenStruct.new(id: 2, name: "B"),
    ]

    loader.send(:merge!, [
      OpenStruct.new(id: 5, widget_id: 1, text: "Detail A"),
      OpenStruct.new(id: 10, widget_id: 2, text: "Detail B"),
    ], widgets)

    assert_equal [
      OpenStruct.new(id: 1, name: "A", detail: OpenStruct.new(id: 5, widget_id: 1, text: "Detail A")),
      OpenStruct.new(id: 2, name: "B", detail: OpenStruct.new(id: 10, widget_id: 2, text: "Detail B")),
    ], widgets
  end

  def test_has_many_query
    ref = Order.reflections.fetch 'line_items'
    loader = OccamsRecord::EagerLoaders::HasMany.new(ref)
    orders = [
      OpenStruct.new(id: 1000),
      OpenStruct.new(id: 1001),
    ]
    loader.send(:query, orders) { |scope|
      assert_equal %q(SELECT "line_items".* FROM "line_items" WHERE "line_items"."order_id" IN (1000, 1001)), scope.to_sql
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

  def test_habtm_query
    ref = User.reflections.fetch 'offices'
    loader = OccamsRecord::EagerLoaders::Habtm.new(ref, ->(q) { q.order('offices.name DESC') })
    users = [
      OpenStruct.new(id: 1000),
      OpenStruct.new(id: 1001),
    ]
    User.connection.execute "INSERT INTO offices_users (user_id, office_id) VALUES (1000, 100), (1000, 101), (1001, 101), (1001, 102), (1002, 103)"

    loader.send(:query, users) { |scope, join_rows|
      assert_equal %q(SELECT "offices".* FROM "offices" WHERE "offices"."id" IN (100, 101, 102) ORDER BY offices.name DESC), scope.to_sql
      assert_equal [[1000, 100], [1000, 101], [1001, 101], [1001, 102]], join_rows
    }
  end

  def test_habtm_merge
    ref = User.reflections.fetch 'offices'
    loader = OccamsRecord::EagerLoaders::Habtm.new(ref)
    users = [
      OpenStruct.new(id: 1000, username: 'bob'),
      OpenStruct.new(id: 1001, username: 'sue'),
    ]
    User.connection.execute "INSERT INTO offices_users (user_id, office_id) VALUES (1000, 100), (1000, 101), (1001, 101), (1001, 102), (1002, 103)"

    loader.send(:merge!, [
      OpenStruct.new(id: 100, name: 'A'),
      OpenStruct.new(id: 101, name: 'B'),
      OpenStruct.new(id: 102, name: 'C'),
      OpenStruct.new(id: 103, name: 'D'),
    ], users, [[1000, 100], [1000, 101], [1001, 101], [1001, 102]])

    assert_equal [
      OpenStruct.new(id: 1000, username: 'bob', offices: [
        OpenStruct.new(id: 100, name: 'A'),
        OpenStruct.new(id: 101, name: 'B'),
      ]),
      OpenStruct.new(id: 1001, username: 'sue', offices: [
        OpenStruct.new(id: 101, name: 'B'),
        OpenStruct.new(id: 102, name: 'C'),
      ]),
    ], users
  end

  def test_habtm_full_with_order
    users = OccamsRecord.
      query(User.order("username ASC")).
      eager_load(:offices, ->(q) { q.order("name DESC") }).
      run

    assert_equal [
      ["bob", ["Foo", "Bar"]],
      ["craig", ["Foo"]],
      ["sue", ["Zorp", "Bar"]]
    ], users.map { |u|
      [u.username, u.offices.map(&:name)]
    }
  end

  def test_eager_load_one_belongs_to_style
    foo, bar = categories(:foo), categories(:bar)
    widgets = [
      OpenStruct.new(id: 100, name: "Widget 1", category_id: foo.id),
      OpenStruct.new(id: 101, name: "Widget 2", category_id: foo.id),
      OpenStruct.new(id: 102, name: "Widget 3", category_id: bar.id),
    ]
    loader = OccamsRecord::EagerLoaders::AdHocOne.new(:category, {:id => :category_id},
      "SELECT * FROM categories WHERE id IN (%{ids})", model: Category)
    loader.run(widgets)

    assert_equal [
      "Widget 1: Foo",
      "Widget 2: Foo",
      "Widget 3: Bar",
    ], widgets.map { |w|
      "#{w.name}: #{w.category&.name}"
    }
  end

  def test_eager_load_one_has_one_style
    widgets = [
      OpenStruct.new(widgets(:a).attributes),
      OpenStruct.new(widgets(:b).attributes),
      OpenStruct.new(widgets(:c).attributes),
    ]
    loader = OccamsRecord::EagerLoaders::AdHocOne.new(:deets, {:widget_id => :id},
      "SELECT * FROM widget_details WHERE widget_id IN (%{ids})", model: WidgetDetail)
    loader.run(widgets)

    assert_equal [
      "Widget A: All about Widget A",
      "Widget B: All about Widget B",
      "Widget C: All about Widget C",
    ], widgets.map { |w|
      "#{w.name}: #{w.deets&.text}"
    }
  end

  def test_eager_load_many
    orders = [
      OpenStruct.new(orders(:a).attributes),
      OpenStruct.new(orders(:b).attributes),
    ]
    loader = OccamsRecord::EagerLoaders::AdHocMany.new(:line_items, {:order_id => :id},
      "SELECT * FROM line_items WHERE order_id IN (%{ids})", model: LineItem)
    loader.run(orders)

    assert_equal [
      "100 = 100",
      "520 = 520",
    ], orders.map { |o|
      sum = o.line_items.reduce(0) { |a, i| a + i.amount }
      "#{o.amount.to_i} = #{sum.to_i}"
    }
  end
end
