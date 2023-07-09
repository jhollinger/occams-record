require 'test_helper'

class RawQueryTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_initializes_correctly
    foo = categories :foo
    q = OccamsRecord::RawQuery.new(
      "SELECT * FROM widgets WHERE category_id = %{cat_id}",
      {cat_id: foo.id}
    )
    assert_equal "SELECT * FROM widgets WHERE category_id = %{cat_id}", q.sql
    assert_equal({cat_id: foo.id}, q.binds)
  end

  def test_simple_query
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id = %{cat_id} ORDER BY name",
        {cat_id: categories(:foo).id}
      ).
      run
    assert_equal ["Widget A", "Widget B", "Widget C"], results.map(&:name)
  end

  def test_simple_query_with_array_binds
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id IN (%{cat_id}) ORDER BY name",
        {cat_id: Category.pluck(:id)}
      ).
      run
    assert_equal ["Widget A", "Widget B", "Widget C", "Widget D", "Widget E", "Widget F", "Widget G"], results.map(&:name)
  end

  def test_positional_query_params
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id = %s AND name IN (%s) ORDER BY name",
        [categories(:foo).id, ["Widget A", "Widget B"]]
      ).
      run
    assert_equal ["Widget A", "Widget B"], results.map(&:name)
  end

  def test_rails_named_query_params
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id = :cat_id AND name IN (:names) ORDER BY name",
        {cat_id: categories(:foo).id, names: ["Widget A", "Widget B"]}
      ).
      run
    assert_equal ["Widget A", "Widget B"], results.map(&:name)
  end

  def test_rails_positional_query_params
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id = ? AND name IN (?) ORDER BY name",
        [categories(:foo).id, ["Widget A", "Widget B"]]
      ).
      run
    assert_equal ["Widget A", "Widget B"], results.map(&:name)
  end

  def test_eager_load
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id = %{cat_id} ORDER BY name",
        {cat_id: categories(:foo).id}
      ).
      model(Widget).
      eager_load(:category).
      run
    assert_equal ["Widget A", "Widget B", "Widget C"], results.map(&:name)
    assert_equal ["Foo", "Foo", "Foo"], results.map { |r| r.category.name }
  end

  def test_find_in_batches
    batches = []
    OccamsRecord.
      sql("SELECT * FROM widgets ORDER BY name LIMIT %{batch_limit} OFFSET %{batch_offset}", {}).
      find_in_batches(batch_size: 2) { |batch|
        batches << batch
      }
    assert_equal [["Widget A", "Widget B"], ["Widget C", "Widget D"], ["Widget E", "Widget F"], ["Widget G"]], batches.map { |b|
      b.map(&:name)
    }
  end

  def test_find_in_batches_with_eager_load
    batches = []
    OccamsRecord.
      sql("SELECT * FROM line_items WHERE amount > %{amount} ORDER BY amount LIMIT %{batch_limit} OFFSET %{batch_offset}", {
        amount: 5,
      }).
      model(LineItem).
      eager_load(:item).
      find_in_batches(batch_size: 2) { |batch|
        batches << batch
      }
    assert_equal [2, 2, 1], batches.map(&:size)
    assert_equal [[20, 30], [70, 200], [300]], batches.map { |b|
      b.map(&:amount)
    }
    assert_equal [["Spline C", "Widget A"], ["Spline A", "Widget C"], ["Widget D"]], batches.map { |b|
      b.map(&:item).map(&:name)
    }
  end
end
