require 'test_helper'

class CursorTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    Time.zone = "Eastern Time (US & Canada)"
    @skip = Widget.connection.class.name =~ /sqlite/i
    $stderr.puts "Skipping CursorTest" if @skip
  end

  def teardown
    DatabaseCleaner.clean
    Time.zone = nil
  end

  def test_cursor
    return if @skip
    widgets = OccamsRecord
      .query(Widget.order("name"))
      .cursor
      .open do |cursor|
        cursor.each(batch_size: 3).to_a
      end
    assert_equal Widget.pluck(:name).sort, widgets.map(&:name).sort
  end

  def test_cursor_with_scope
    return if @skip
    widgets = OccamsRecord
      .query(Widget.all)
      .find_each_with_cursor
      .to_a
    assert_equal Widget.pluck(:name).sort, widgets.map(&:name).sort
  end

  def test_cursor_batches_with_scope
    return if @skip
    batches = OccamsRecord
      .query(Widget.order("name"))
      .find_in_batches_with_cursor(batch_size: 3)
      .map { |batch|
        batch.map(&:name)
      }
    assert_equal [
      ["Widget A", "Widget B", "Widget C"],
      ["Widget D", "Widget E", "Widget F"],
      ["Widget G"],
    ], batches
  end

  def test_eager_loading_with_scope
    return if @skip
    widgets = OccamsRecord
      .query(Widget.order("name"))
      .eager_load(:category)
      .find_each_with_cursor(batch_size: 3)
      .to_a
    assert_equal %w(
      Foo
      Foo
      Foo
      Bar
      Bar
      Bar
      Bar
    ), widgets.map { |w| w.category.name }
  end

  def test_cursor_with_sql
    return if @skip
    widgets = OccamsRecord
      .sql("SELECT * FROM widgets", {})
      .find_each_with_cursor
      .to_a
    assert_equal Widget.pluck(:name).sort, widgets.map(&:name).sort
  end

  def test_cursor_batches_with_sql
    return if @skip
    batches = OccamsRecord
      .sql("SELECT * FROM widgets ORDER BY name", {})
      .find_in_batches_with_cursor(batch_size: 3)
      .map { |batch|
        batch.map(&:name)
      }
    assert_equal [
      ["Widget A", "Widget B", "Widget C"],
      ["Widget D", "Widget E", "Widget F"],
      ["Widget G"],
    ], batches
  end

  def test_eager_loading_with_sql
    return if @skip
    widgets = OccamsRecord
      .sql("SELECT * FROM widgets ORDER BY name", {})
      .model(Widget)
      .eager_load(:category)
      .find_each_with_cursor(batch_size: 3)
      .to_a
    assert_equal %w(
      Foo
      Foo
      Foo
      Bar
      Bar
      Bar
      Bar
    ), widgets.map { |w| w.category.name }
  end
end
