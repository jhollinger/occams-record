require 'test_helper'

class EagerLoadingAdHocTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
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
end
