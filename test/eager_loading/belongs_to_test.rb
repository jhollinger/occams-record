require 'test_helper'

class EagerLoadingBelongsToTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_belongs_to_query
    ref = Widget.reflections.fetch 'category'
    loader = OccamsRecord::EagerLoaders::BelongsTo.new(ref, ->(q) { q.where(name: 'Foo') })
    widgets = [
      OpenStruct.new(category_id: 5),
      OpenStruct.new(category_id: 10),
    ]
    loader.send(:query, widgets) { |scope|
      assert_equal %q(SELECT categories.* FROM categories WHERE categories.name = 'Foo' AND categories.id IN (5, 10)), normalize_sql(scope.to_sql)
    }
  end

  def test_belongs_to_merge
    ref = Widget.reflections.fetch 'category'
    loader = OccamsRecord::EagerLoaders::BelongsTo.new(ref)
    widgets = [
      OpenStruct.new(id: 1, name: "A", category_id: 5),
      OpenStruct.new(id: 2, name: "B", category_id: 10),
    ]

    loader.send(:merge!, [
      OpenStruct.new(id: 5, name: "Cat A"),
      OpenStruct.new(id: 10, name: "Cat B"),
    ], widgets)

    assert_equal [
      OpenStruct.new(id: 1, name: "A", category_id: 5, category: OpenStruct.new(id: 5, name: "Cat A")),
      OpenStruct.new(id: 2, name: "B", category_id: 10, category: OpenStruct.new(id: 10, name: "Cat B")),
    ], widgets
  end

  def test_belongs_to_merge_with_key_overrides
    ref = Category.reflections.fetch "category_type"
    loader = OccamsRecord::EagerLoaders::BelongsTo.new(ref)
    cats = [
      OpenStruct.new(id: 1, type_code: "a", name: "Foo"),
      OpenStruct.new(id: 2, type_code: "b", name: "Bar"),
    ]

    loader.send(:merge!, [
      OpenStruct.new(id: 1234, code: "a", description: "Type A"),
      OpenStruct.new(id: 5678, code: "b", description: "Type B"),
      OpenStruct.new(id: 9123, code: "c", description: "Type C"),
    ], cats)

    assert_equal [
      OpenStruct.new(id: 1, type_code: "a", name: "Foo", category_type: OpenStruct.new(id: 1234, code: "a", description: "Type A")),
      OpenStruct.new(id: 2, type_code: "b", name: "Bar", category_type: OpenStruct.new(id: 5678, code: "b", description: "Type B")),
    ], cats
  end

  def test_belongs_to
    results = OccamsRecord.
      query(Widget.all).
      eager_load(:category).
      run

    assert_equal Widget.all.map { |w|
      "#{w.name}: #{w.category.name}"
    }.sort, results.map { |w|
      "#{w.name}: #{w.category.name}"
    }.sort
  end
end
