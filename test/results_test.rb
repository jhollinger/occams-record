require 'test_helper'

class ResultsTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    Time.zone = "Eastern Time (US & Canada)"
  end

  def teardown
    DatabaseCleaner.clean
    Time.zone = nil
  end

  def test_including_module
    mod_a, mod_b, mod_c = Module.new, Module.new, Module.new
    orders = OccamsRecord.
      query(Order.all, use: mod_a).
      eager_load(:line_items, use: mod_b) {
        eager_load(:item, use: mod_c)
      }.
      run

    assert_equal Order.count, orders.size
    orders.each do |order|
      assert order.is_a?(mod_a)
      refute order.is_a?(mod_b)
      refute order.is_a?(mod_c)

      assert order.line_items.any?
      refute order.line_items.all? { |line_item| line_item.is_a? mod_a }
      assert order.line_items.all? { |line_item| line_item.is_a? mod_b }
      refute order.line_items.all? { |line_item| line_item.is_a? mod_c }

      assert order.line_items.map(&:item).compact.any?
      refute order.line_items.all? { |line_item| line_item.item.is_a? mod_a }
      refute order.line_items.all? { |line_item| line_item.item.is_a? mod_b }
      assert order.line_items.all? { |line_item| line_item.item.is_a? mod_c }
    end
  end

  def test_including_multiple_modules
    mod_a, mod_b, mod_c = Module.new, Module.new, Module.new
    orders = OccamsRecord.
      query(Order.all, use: [mod_a, mod_b]).
      eager_load(:line_items, use: mod_b) {
        eager_load(:item, use: mod_c) {
          eager_load(:category, use: [mod_a, mod_c])
        }
      }.
      run

    assert_equal Order.count, orders.size
    orders.each do |order|
      assert order.is_a?(mod_a)
      assert order.is_a?(mod_b)
      refute order.is_a?(mod_c)

      assert order.line_items.any?
      refute order.line_items.all? { |line_item| line_item.is_a? mod_a }
      assert order.line_items.all? { |line_item| line_item.is_a? mod_b }
      refute order.line_items.all? { |line_item| line_item.is_a? mod_c }

      assert order.line_items.map(&:item).compact.any?
      refute order.line_items.all? { |line_item| line_item.item.is_a? mod_a }
      refute order.line_items.all? { |line_item| line_item.item.is_a? mod_b }
      assert order.line_items.all? { |line_item| line_item.item.is_a? mod_c }

      assert order.line_items.map(&:item).map(&:category).compact.any?
      assert order.line_items.all? { |line_item| line_item.item.category.is_a? mod_a }
      refute order.line_items.all? { |line_item| line_item.item.category.is_a? mod_b }
      assert order.line_items.all? { |line_item| line_item.item.category.is_a? mod_c }
    end
  end

  def test_boolean_aliases
    offices(:bar).update_column(:active, true)
    offices(:foo).update_column(:active, false)
    offices(:zorp).update_column(:active, nil)

    offices = OccamsRecord.query(Office.order("name")).run
    assert_equal [true, false, false], offices.map(&:active?)
  end

  def test_raises_special_exception_for_missing_eager_load
    widget = OccamsRecord.query(Widget.limit(1)).run.first
    e = assert_raises OccamsRecord::MissingEagerLoadError do
      widget.category
    end
    assert_equal :category, e.name
    assert_equal "Widget", e.model_name
    assert_equal "Association 'category' is unavailable on Widget because it was not eager loaded! Occams Record trace: root", e.message
  end

  def test_includes_load_path_in_missing_eager_loads
    widgets = OccamsRecord.
      query(Customer.all).
      eager_load(:orders) {
        eager_load(:line_items)
      }.
      run

    e = assert_raises OccamsRecord::MissingEagerLoadError do
      widgets[0].orders[0].line_items[0].category
    end
    assert_equal :category, e.name
    assert_equal "LineItem", e.model_name
    assert_equal "Association 'category' is unavailable on LineItem because it was not eager loaded! Occams Record trace: root.orders.line_items", e.message
  end

  def test_raises_special_exception_for_missing_column
    widget = OccamsRecord.query(Widget.select("id").limit(1)).run.first
    e = assert_raises OccamsRecord::MissingColumnError do
      widget.name
    end
    assert_equal :name, e.name
    assert_equal "Widget", e.model_name
    assert_equal "Column 'name' is unavailable on Widget because it was not included in the SELECT statement! Occams Record trace: root", e.message
  end

  def test_includes_load_path_in_missing_columns
    widgets = OccamsRecord.
      query(Customer.all).
      eager_load(:orders) {
        eager_load(:line_items, select: "id, order_id")
      }.
      run

    e = assert_raises OccamsRecord::MissingColumnError do
      widgets[0].orders[0].line_items[0].amount
    end
    assert_equal :amount, e.name
    assert_equal "LineItem", e.model_name
    assert_equal "Column 'amount' is unavailable on LineItem because it was not included in the SELECT statement! Occams Record trace: root.orders.line_items", e.message
  end

  def test_raises_normal_method_missing_for_unknown_method
    widget = OccamsRecord.query(Widget.limit(1)).run.first
    assert_raises NoMethodError do
      widget.foo
    end
  end

  def test_raises_method_missing_with_eager_load_trace
    widgets = OccamsRecord.
      query(Widget.all).
      eager_load(:category).
      run
    e = assert_raises NoMethodError do
      widgets[0].category.foo
    end
    assert_match(/Undefined method `foo'/, e.message)
    assert_match(/Occams Record trace: root.category/, e.message)
  end

  def test_to_s
    widget1 = OccamsRecord.query(Widget.order(:name)).first
    attrs = {id: 683130438, name: "Widget A", category_id: 208889123}
    assert_equal "Widget#{attrs.inspect}", widget1.to_s
  end

  def test_object_equality
    widget1 = OccamsRecord.query(Widget.all).first
    widget2 = OccamsRecord.query(Widget.all).first
    widget3 = OccamsRecord.query(Widget.all).run.last

    assert widget1 == widget2
    refute widget1 == widget3
    refute widget1 == OpenStruct.new(id: widget1.id)
  end

  def test_object_hash_access
    widget1 = OccamsRecord.query(Widget.all).eager_load(:category).first
    assert_equal widget1.name, widget1[:name]
    assert_equal widget1.name, widget1["name"]
    assert_equal widget1.category.name, widget1[:category][:name]
    assert_equal widget1.category.name, widget1["category"]["name"]
  end
end
