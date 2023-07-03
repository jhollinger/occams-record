require 'test_helper'

class EagerLoadingIdsTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_loads_ids
    Category.delete_all
    CategoryType.delete_all

    CategoryType.create!(code: "a", description: "A")
    c1 = Category.create!(type_code: "a", name: "Foo")
    c2 = Category.create!(type_code: "a", name: "Bar")

    _t2 = CategoryType.create!(code: "b", description: "B")
    c3 = Category.create!(type_code: "b", name: "Zorp")
    c4 = Category.create!(type_code: "b", name: "Gulb")

    types = OccamsRecord.
      query(CategoryType.order(:description)).
      eager_load(:categories, ->(q) { q.order(:name) }).
      run

    assert_equal [
      "A: #{c2.id}, #{c1.id}",
      "B: #{c4.id}, #{c3.id}",
    ], types.map { |t|
      "#{t.description}: #{t.category_ids.map(&:to_s).join(", ")}"
    }
  end

  def test_ids_are_discoverable
    type = OccamsRecord.
      query(CategoryType.order(:description)).
      eager_load(:categories, ->(q) { q.order(:name) }).
      first

    assert type.respond_to?(:category_ids)
  end
end
