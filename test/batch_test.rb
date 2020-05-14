require 'test_helper'

class BatchTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_find_in_batches_with_block
    num_calls = 0
    widgets = []
    OccamsRecord.query(Widget.order('name')).find_in_batches(batch_size: 3) do |batch|
      num_calls += 1
      batch.each { |widget| widgets << widget.name }
    end
    assert_equal 3, num_calls
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E', 'Widget F', 'Widget G'], widgets
  end

  def test_find_each_with_block
    widgets = []
    OccamsRecord.query(Widget.order('name')).find_each(batch_size: 3) do |widget|
      widgets << widget.name
    end
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E', 'Widget F', 'Widget G'], widgets
  end

  def test_find_each_with_block_and_large_number
    Widget.delete_all
    Widget.connection.execute "INSERT INTO widgets (name) VALUES " + 3338.times.map { |i| "('Widget #{i}')" }.join(", ")
    assert_equal 3338, Widget.count

    n = 0
    OccamsRecord.query(Widget.order('name').where("1=1")).find_each do |widget|
      n += 1
    end
    assert_equal 3338, n
  end

  def test_find_in_batches_with_enum
    widgets = OccamsRecord.
      query(Widget.order('name')).
      find_in_batches.
      reduce([]) { |a, batch|
        a + batch.map(&:name)
      }
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E', 'Widget F', 'Widget G'], widgets
  end

  def test_find_each_with_enum
    widgets = OccamsRecord.
      query(Widget.order('name')).
      find_each.
      map(&:name)
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E', 'Widget F', 'Widget G'], widgets
  end

  def test_batches_with_offset
    widgets = OccamsRecord.
      query(Widget.order('name').offset(3)).
      find_each.
      map(&:name)
    assert_equal ['Widget D', 'Widget E', 'Widget F', 'Widget G'], widgets
  end

  def test_batches_with_limit
    widgets = OccamsRecord.
      query(Widget.order('name').limit(3)).
      find_each.
      map(&:name)
    assert_equal ['Widget A', 'Widget B', 'Widget C'], widgets
  end

  def test_batches_with_batch_remainder
    widgets = OccamsRecord.
      query(Widget.order('name').limit(5)).
      find_each(batch_size: 3).
      map(&:name)
    assert_equal ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E'], widgets
  end

  def test_eager_loading_with_batches
    widgets = OccamsRecord.
      query(Widget.order('name').limit(3).offset(1)).
      eager_load(:category).
      eager_load(:detail).
      eager_load(:line_items) {
        eager_load(:order)
      }.
      find_each(batch_size: 2).
      map { |w|
        {name: w.name, category: w.category.name, detail: w.detail.text, line_items: w.line_items.map { |li|
          {amount: li.amount.to_i, total: li.order.amount.to_i}
        }}
      }

    assert_equal [
      {name: 'Widget B', category: 'Foo', detail: 'All about Widget B', line_items: []},
      {name: 'Widget C', category: 'Foo', detail: 'All about Widget C', line_items: [
        {amount: 200, total: 520}
      ]},
      {name: 'Widget D', category: 'Bar', detail: 'All about Widget D', line_items: [
        {amount: 300, total: 520}
      ]},
    ], widgets
  end

  def test_batches_orders_by_pkey
    log = []
    OccamsRecord.
      query(Widget.all, query_logger: log).
      find_each(batch_size: 1000).
      to_a
    assert_includes log.map { |x|
      x.gsub(/\s+/, " ")
    }, %(SELECT "widgets".* FROM "widgets" ORDER BY "widgets"."id" ASC LIMIT 1000 OFFSET 0)
  end

  def test_batches_orders_by_custom_and_pkey
    log = []
    OccamsRecord.
      query(Widget.order(:name), query_logger: log).
      find_each(batch_size: 1000).
      to_a
    assert_includes log.map { |x|
      x.gsub(/\s+/, " ")
    }, %(SELECT "widgets".* FROM "widgets" ORDER BY "widgets"."name" ASC, "widgets"."id" ASC LIMIT 1000 OFFSET 0)
  end

  def test_batches_orders_by_pkey_with_select_star
    log = []
    OccamsRecord.
      query(Widget.select("widgets.*, 1 AS one"), query_logger: log).
      find_each(batch_size: 1000).
      to_a
    assert_includes log.map { |x|
      x.gsub(/\s+/, " ")
    }, %(SELECT widgets.*, 1 AS one FROM "widgets" ORDER BY "widgets"."id" ASC LIMIT 1000 OFFSET 0)
  end

  def test_batches_orders_by_pkey_with_select_pkey_str
    log = []
    OccamsRecord.
      query(Widget.select("widgets.id"), query_logger: log).
      find_each(batch_size: 1000).
      to_a
    assert_includes log.map { |x|
      x.gsub(/\s+/, " ")
    }, %(SELECT widgets.id FROM "widgets" ORDER BY "widgets"."id" ASC LIMIT 1000 OFFSET 0)
  end

  def test_batches_orders_by_pkey_with_select_pkey_sym
    log = []
    OccamsRecord.
      query(Widget.select(:id), query_logger: log).
      find_each(batch_size: 1000).
      to_a
    assert_includes log.map { |x|
      x.gsub(/\s+/, " ")
    }, %(SELECT "widgets"."id" FROM "widgets" ORDER BY "widgets"."id" ASC LIMIT 1000 OFFSET 0)
  end

  def test_batches_doesnt_order_by_pkey_without_pkey_in_select
    log = []
    OccamsRecord.
      query(Widget.select(:name), query_logger: log).
      find_each(batch_size: 1000).
      to_a
    assert_includes log.map { |x|
      x.gsub(/\s+/, " ")
    }, %(SELECT "widgets"."name" FROM "widgets" LIMIT 1000 OFFSET 0)
  end
end
