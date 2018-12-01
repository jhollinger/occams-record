require 'test_helper'

class MergeTest < Minitest::Test
  include TestHelpers

  def test_merges_single_with_one_key_pair
    records = [
      OpenStruct.new(name: "A", category_id: 1),
      OpenStruct.new(name: "B", category_id: 1),
      OpenStruct.new(name: "C", category_id: 2),
      OpenStruct.new(name: "C", category_id: 3),
    ]

    OccamsRecord::Merge.new(records, :category).single!([
      OpenStruct.new(id: 1, name: "Foo"),
      OpenStruct.new(id: 2, name: "Bar"),
      OpenStruct.new(id: 4, name: "Zorp"),
    ], {:category_id => :id})

    assert_equal [
      "Foo",
      "Foo",
      "Bar",
      nil
    ], records.map { |r|
      r.category&.name
    }
  end

  def test_merges_single_with_two_key_pairs
    records = [
      OpenStruct.new(name: "A", category_id: 1, category_type: "Cat1"),
      OpenStruct.new(name: "B", category_id: 1, category_type: "Cat2"),
      OpenStruct.new(name: "C", category_id: 2, category_type: "Cat1"),
      OpenStruct.new(name: "C", category_id: 3, category_type: "Cat1"),
    ]

    OccamsRecord::Merge.new(records, :category).single!([
      OpenStruct.new(id: 1, type: "Cat1", name: "Foo"),
      OpenStruct.new(id: 2, type: "Cat1", name: "Bar"),
      OpenStruct.new(id: 4, type: "Cat1", name: "Zorp"),
    ], {:category_id => :id, :category_type => :type})

    assert_equal [
      "Foo",
      nil,
      "Bar",
      nil
    ], records.map { |r|
      r.category&.name
    }
  end

  def test_merges_many_with_one_key_pair
    categories = [
      OpenStruct.new(id: 1, name: "Foo"),
      OpenStruct.new(id: 2, name: "Bar"),
      OpenStruct.new(id: 4, name: "Zorp"),
    ]

    OccamsRecord::Merge.new(categories, :records).many!([
      OpenStruct.new(name: "A", category_id: 1),
      OpenStruct.new(name: "B", category_id: 1),
      OpenStruct.new(name: "C", category_id: 2),
      OpenStruct.new(name: "C", category_id: 3),
    ], {:id => :category_id})

    assert_equal [
      "Foo: A, B",
      "Bar: C",
      "Zorp: ",
    ], categories.map { |c|
      "#{c.name}: #{c.records.map(&:name).join ", "}"
    }
  end

  def test_merges_many_with_two_key_pairs
    categories = [
      OpenStruct.new(id: 1, type: "Cat1", name: "Foo"),
      OpenStruct.new(id: 2, type: "Cat1", name: "Bar"),
      OpenStruct.new(id: 4, type: "Cat1", name: "Zorp"),
    ]

    OccamsRecord::Merge.new(categories, :records).many!([
      OpenStruct.new(name: "A", category_id: 1, category_type: "Cat1"),
      OpenStruct.new(name: "B", category_id: 1, category_type: "Cat2"),
      OpenStruct.new(name: "C", category_id: 2, category_type: "Cat1"),
      OpenStruct.new(name: "C", category_id: 3, category_type: "Cat1"),
    ], {:id => :category_id, :type => :category_type})

    assert_equal [
      "Foo: A",
      "Bar: C",
      "Zorp: ",
    ], categories.map { |c|
      "#{c.name}: #{c.records.map(&:name).join ", "}"
    }
  end
end
