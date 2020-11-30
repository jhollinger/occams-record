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

  def test_belongs_to_merge_with_key_overrides
    ref = Category.reflections.fetch "category_type"
    loader = OccamsRecord::EagerLoaders::BelongsTo.new(ref)
    cats = [
      OpenStruct.new(id: 1, type_code: "a", name: "Foo"),
      OpenStruct.new(id: 2, type_code: "b", name: "Bar"),
    ]

    loader.send(:merge!, [
      OpenStruct.new(id: 1234, code: "a", description: "Type A"),
      OpenStruct.new(id: 5678, code: "b", description: "Type B"),
      OpenStruct.new(id: 9123, code: "c", description: "Type C"),
    ], cats)

    assert_equal [
      OpenStruct.new(id: 1, type_code: "a", name: "Foo", category_type: OpenStruct.new(id: 1234, code: "a", description: "Type A")),
      OpenStruct.new(id: 2, type_code: "b", name: "Bar", category_type: OpenStruct.new(id: 5678, code: "b", description: "Type B")),
    ], cats
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

  def test_has_one_view_of_has_many
    jane = customers :jane
    Order.create!(customer_id: jane.id, date: "2019-01-01", amount: 100)

    jon = customers :jon
    Order.create!(customer_id: jon.id, date: "2019-02-01", amount: 120)

    customers = OccamsRecord.
      query(Customer.order("name")).
      eager_load(:latest_order).
      run

    assert_equal [
      "Jane 2019-01-01: 100",
      "Jon 2019-02-01: 120",
    ], customers.map { |c|
      "#{c.name} #{c.latest_order.date.iso8601}: #{c.latest_order.amount.to_i}"
    }
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
      assert_equal %q(SELECT "offices".* FROM "offices" WHERE "offices"."id" IN (100, 101, 102) ORDER BY offices.name DESC), scope.to_sql.gsub(/\s+/, " ")
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

  def test_habtm_makes_empty_arrays_even_if_there_are_no_associated_records
    User.connection.execute "DELETE FROM offices_users"
    results = OccamsRecord.
      query(User.all).
      eager_load(:offices).
      map do |user|
        user.offices
      end
    refute results.any?(&:nil?)
  end

  def test_eager_load_one_belongs_to_style
    foo, bar = categories(:foo), categories(:bar)
    widgets = [
      OpenStruct.new(id: 100, name: "Widget 1", category_id: foo.id),
      OpenStruct.new(id: 101, name: "Widget 2", category_id: foo.id),
      OpenStruct.new(id: 102, name: "Widget 3", category_id: bar.id),
    ]
    loader = OccamsRecord::EagerLoaders::AdHocOne.new(:category, {:category_id => :id},
      "SELECT * FROM categories WHERE id IN (%{category_ids})", model: Category)
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
    loader = OccamsRecord::EagerLoaders::AdHocOne.new(:deets, {:id => :widget_id},
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
    loader = OccamsRecord::EagerLoaders::AdHocMany.new(:line_items, {:id => :order_id},
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

  def test_eager_load_one_and_many
    widgets = OccamsRecord.
      query(Widget.order("name").limit(4)).
      eager_load_one(:category, {:category_id => :id}, %(
        SELECT * FROM categories WHERE id IN (%{category_ids}) AND name != %{bad_name}
      ), binds: {
        bad_name: "Bad category"
      }, model: Category) {
        eager_load_many(:splines, {:id => :category_id},
          "SELECT * FROM splines WHERE category_id IN (%{ids})", model: Spline)
      }.
      run

      assert_equal [
        "Widget A: Foo (2 splines in category)",
        "Widget B: Foo (2 splines in category)",
        "Widget C: Foo (2 splines in category)",
        "Widget D: Bar (1 splines in category)",
      ], widgets.map { |w|
        "#{w.name}: #{w.category&.name} (#{w.category&.splines&.size} splines in category)"
      }
  end

  def test_eager_load_one_and_many_with_zero_parents
    widgets = OccamsRecord.
      query(Widget.where(name: "Does Not Exist")).
      eager_load_one(:category, {:category_id => :id}, %(
        SELECT * FROM categories WHERE id IN (%{category_ids}) AND name != %{bad_name}
      ), binds: {
        bad_name: "Bad category"
      }, model: Category).
      eager_load_many(:line_items, {:id => :item_id},
        "SELECT * FROM line_items WHERE item_id IN (%{ids}) AND item_type = 'Widget'", model: LineItem
      ).
      run

      assert_equal [
      ], widgets.map { |w|
        "#{w.name}: #{w.category&.name} (#{w.category&.line_items&.size} line_items in category)"
      }
  end

  def test_eager_load_as_a_custom_name
    widgets = OccamsRecord.
      query(Widget.order(:name)).
      eager_load(:category, as: :cat).
      run

    assert_equal [
      "Widget A: Foo",
      "Widget B: Foo",
      "Widget C: Foo",
      "Widget D: Bar",
      "Widget E: Bar",
      "Widget F: Bar",
      "Widget G: Bar",
    ], widgets.map { |w|
      "#{w.name}: #{w.cat.name}"
    }
  end

  def test_eager_load_a_custom_name_from_a_real_assoc
    widgets = OccamsRecord.
      query(Widget.order(:name)).
      eager_load(:cat, from: :category).
      run

    assert_equal [
      "Widget A: Foo",
      "Widget B: Foo",
      "Widget C: Foo",
      "Widget D: Bar",
      "Widget E: Bar",
      "Widget F: Bar",
      "Widget G: Bar",
    ], widgets.map { |w|
      "#{w.name}: #{w.cat.name}"
    }
  end

  def test_loads_ids
    Category.delete_all
    CategoryType.delete_all

    CategoryType.create!(code: "a", description: "A")
    c1 = Category.create!(type_code: "a", name: "Foo")
    c2 = Category.create!(type_code: "a", name: "Bar")

    _t2 = CategoryType.create!(code: "b", description: "B")
    c3 = Category.create!(type_code: "b", name: "Zorp")
    c4 = Category.create!(type_code: "b", name: "Gulb")

    types = OccamsRecord.
      query(CategoryType.order(:description)).
      eager_load(:categories, ->(q) { q.order(:name) }).
      run

    assert_equal [
      "A: #{c2.id}, #{c1.id}",
      "B: #{c4.id}, #{c3.id}",
    ], types.map { |t|
      "#{t.description}: #{t.category_ids.map(&:to_s).join(", ")}"
    }
  end

  def test_ids_are_discoverable
    type = OccamsRecord.
      query(CategoryType.order(:description)).
      eager_load(:categories, ->(q) { q.order(:name) }).
      first

    assert type.respond_to?(:category_ids)
  end

  def test_non_standard_pkey_name
    i1 = Icd10.create!(code: "W61.12XD", name: "Struck by macaw, subsequent encounter")
    HealthCondition.create!(name: "Hurt by bird", icd10_id: i1.id)

    res = OccamsRecord.
      query(HealthCondition.all).
      eager_load(:icd10).
      run

    assert_equal [
      "W61.12XD Hurt by bird",
    ], res.map { |x|
      "#{x.icd10.code} #{x.name}"
    }
  end
end
