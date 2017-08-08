require 'test_helper'

class QueryTest < Minitest::Test
  include TestHelpers

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
    results = MicroRecord.query(Category.all.order('name')).run
    assert_equal %w(Bar Foo), results.map(&:name)
  end

  def test_custom_select
    order = Order.create!(date: Date.new(2017, 2, 28), amount: 56.72, customer_id: 42)

    results = MicroRecord.query(Order.select('amount, id, date, customer_id')).run
    assert_equal 1, results.size
    assert_equal OpenStruct.new(
      amount: 56.72,
      id: order.id,
      date: Date.new(2017, 2, 28),
      customer_id: 42
    ), results[0]
  end
end
