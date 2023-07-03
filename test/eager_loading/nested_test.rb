require 'test_helper'

class EagerLoadingNestedTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_nested_eager_load_without_block_arg
    test = self
    cats = OccamsRecord.
      query(Category.order(:name)).
      eager_load(:widgets) {
        scope { |q| test.apply_order q, :name }
        eager_load(:detail)
      }.
      run

    assert_equal [
      "Bar: (Widget D - All about Widget D), (Widget E - All about Widget E), (Widget F - All about Widget F), (Widget G - All about Widget G)",
      "Foo: (Widget A - All about Widget A), (Widget B - All about Widget B), (Widget C - All about Widget C)",
    ], cats.map { |cat|
      data = cat.widgets.map { |w| "(#{w.name} - #{w.detail.text})" }
      "#{cat.name}: #{data.join ', '}"
    }
  end

  def test_nested_eager_load_with_block_arg
    cats = OccamsRecord.
      query(Category.order(:name)).
      eager_load(:widgets) { |l|
        l.scope { |q| apply_order q, :name }
        l.eager_load(:detail)
      }.
      run

    assert_equal [
      "Bar: (Widget D - All about Widget D), (Widget E - All about Widget E), (Widget F - All about Widget F), (Widget G - All about Widget G)",
      "Foo: (Widget A - All about Widget A), (Widget B - All about Widget B), (Widget C - All about Widget C)",
    ], cats.map { |cat|
      data = cat.widgets.map { |w| "(#{w.name} - #{w.detail.text})" }
      "#{cat.name}: #{data.join ', '}"
    }
  end

  def test_nested
    log = []
    results = OccamsRecord.
      query(Category.all, query_logger: log).
      eager_load(:widgets) {
        eager_load(:detail)
      }.
      run

    assert_equal [
      %q(root: SELECT categories.* FROM categories),
      %q(root.widgets: SELECT widgets.* FROM widgets WHERE widgets.category_id IN (208889123, 922717355)),
      %q(root.widgets.detail: SELECT widget_details.* FROM widget_details WHERE widget_details.widget_id IN (30677878, 112844655, 417155790, 683130438, 802847325, 834596858, 919808993)),
    ], log.map { |x|
      normalize_sql x
    }

    assert_equal Category.all.map { |c|
      {
        id: c.id,
        type_code: c.type_code,
        name: c.name,
        widgets: c.widgets.map { |w|
          {
            id: w.id,
            name: w.name,
            category_id: w.category_id,
            detail: {
              id: w.detail.id,
              widget_id: w.detail.widget_id,
              text: w.detail.text
            }
          }
        }
      }
    }, results.map { |r| r.to_hash(symbolize_names: true, recursive: true) }
  end

  def apply_order(q, val)
    q.order(val)
  end
end
