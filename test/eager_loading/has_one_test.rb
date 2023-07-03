require 'test_helper'

class EagerLoadingHasOneTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_has_one_query
    ref = Widget.reflections.fetch 'detail'
    loader = OccamsRecord::EagerLoaders::HasOne.new(ref)
    widgets = [
      OpenStruct.new(id: 1),
      OpenStruct.new(id: 52),
    ]
    loader.send(:query, widgets) { |scope|
      assert_equal %q(SELECT widget_details.* FROM widget_details WHERE widget_details.widget_id IN (1, 52)), normalize_sql(scope.to_sql)
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

  def test_has_one
    results = OccamsRecord.
      query(Widget.all).
      eager_load(:detail).
      run

    assert_equal Widget.all.map { |w|
      "#{w.name}: #{w.detail.text}"
    }.sort, results.map { |w|
      "#{w.name}: #{w.detail.text}"
    }.sort
  end
end
