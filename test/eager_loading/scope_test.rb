require 'test_helper'

class EagerLoadingScopeTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_multiple_scopes
    users = OccamsRecord.
      query(User.order("username ASC")).
      eager_load(:offices) {
        scope { |q| q.order("name DESC") }
        scope { |q| q.where.not("name = ?", 'Zorp') }
      }.
      run

    assert_equal [
      ["bob", ["Foo", "Bar"]],
      ["craig", ["Foo"]],
      ["sue", ["Bar"]]
    ], users.map { |u|
      [u.username, u.offices.map(&:name)]
    }
  end

  def test_eager_load_with_none
    cats = OccamsRecord.
      query(Category.all).
      eager_load(:widgets, ->(q) { q.none }).
      run

    assert_equal [], cats.reduce([]) { |acc, cat|
      acc + cat.widgets
    }
  end

  def test_eager_load_with_default_scope
    log = []
    results = OccamsRecord.
      query(Order.all, query_logger: log).
      eager_load(:ordered_line_items, ->(q) { q.where('1 != 2') }).
      run

    assert_equal LineItem.count, results.map(&:ordered_line_items).flatten.size
    assert_includes log.map { |x|
      normalize_sql x
    }, %q(root.ordered_line_items: SELECT line_items.* FROM line_items WHERE (1 != 2) AND line_items.order_id IN (683130438, 834596858) ORDER BY item_type)
  end

  def test_eager_load_custom_select_from_proc
    log = []
    results = OccamsRecord.
      query(Order.all, query_logger: log).
      eager_load(:line_items, ->(q) { q.where('1 != 2') }).
      run

    assert_equal LineItem.count, results.map(&:line_items).flatten.size
    assert_includes log.map { |x|
      normalize_sql x
    } , %q(root.line_items: SELECT line_items.* FROM line_items WHERE (1 != 2) AND line_items.order_id IN (683130438, 834596858))
  end

  def test_eager_load_custom_select_from_string
    log = []
    results = OccamsRecord.
      query(Order.all, query_logger: log).
      eager_load(:line_items, select: "id, order_id").
      run

    assert_equal LineItem.count, results.map(&:line_items).flatten.size
    assert_includes log.map { |x|
      normalize_sql x
    }, %q(root.line_items: SELECT id, order_id FROM line_items WHERE line_items.order_id IN (683130438, 834596858))
  end
end
