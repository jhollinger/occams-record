require 'test_helper'

class MeasurementTest < Minitest::Test
  def test_top_level_query
    m = nil
    OccamsRecord.
      query(Widget.all).
      measure { |measurements|
        m = measurements
      }.
      run

    refute_nil m
    assert_operator m.total_time, :>, 0
    assert_equal %w(widgets), m.queries.map(&:table_name)
    assert_operator m.queries[0].time, :>, 0
    refute_nil m.queries[0].sql
  end

  def test_nested_queries
    m = nil
    OccamsRecord.
      query(Order.all).
      eager_load(:customer).
      eager_load(:line_items) {
        eager_load(:item)
        eager_load(:category)
      }.
      measure { |measurements|
        m = measurements
      }.
      run

    refute_nil m
    assert_operator m.total_time, :>, 0
    assert_equal %w(
      categories
      customers
      line_items
      orders
      splines
      widgets
    ).sort, m.queries.map(&:table_name).sort
  end

  def test_raw_queries
    m = nil
    OccamsRecord.
      sql("SELECT * FROM widgets", {}).
      model(Widget).
      eager_load_one(:category, {:category_id => :id}, "
        SELECT * FROM categories WHERE id IN (%{category_ids})
      ", model: Category).
      measure { |measurements|
        m = measurements
      }.
      run

    refute_nil m
    assert_operator m.total_time, :>, 0
    assert_equal %w(
      categories
      widgets
    ).sort, m.queries.map(&:table_name).sort
  end
end
