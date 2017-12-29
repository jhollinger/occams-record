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
      model(Widget). # NOTE this is only necessary with SQLite
      run
    assert_equal ["Widget A", "Widget B", "Widget C"], results.map(&:name)
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
end
