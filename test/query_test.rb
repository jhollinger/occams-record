require 'test_helper'

class QueryTest < Minitest::Test
  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_initializes_correctly
    q = MicroRecord::Query.new(Category.all)
    assert_equal Category, q.model
    assert_match %r{SELECT}, q.sql
    assert q.native_types
    assert_equal 0, q.eager_loaders.size
    refute_nil q.conn
  end

  def test_simple_query
    Category.create!(name: 'Foo')
    Category.create!(name: 'Bar')

    results = MicroRecord.query(Category.all.order('name')).run
    assert_equal 2, results.size
    assert_equal %w(Bar Foo), results.map(&:name)
  end
end
