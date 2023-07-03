require 'test_helper'

class QueryTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    Time.zone = "Eastern Time (US & Canada)"
  end

  def teardown
    DatabaseCleaner.clean
    Time.zone = nil
  end

  def test_initializes_correctly
    q = OccamsRecord::Query.new(Category.all)
    assert_equal Category, q.model
    assert_match %r{SELECT}, q.scope.to_sql
  end

  def test_simple_query
    results = OccamsRecord.query(Category.all.order('name')).run
    assert_equal %w(Bar Foo), results.map(&:name)
  end

  def test_simple_query_with_each
    enum = OccamsRecord.query(Category.all.order('name')).each
    results = enum.to_a
    assert_equal %w(Bar Foo), results.map(&:name)
  end

  def test_simple_query_with_each_block
    results = []
    OccamsRecord.query(Category.all.order('name')).each { |row| results << row }
    assert_equal %w(Bar Foo), results.map(&:name)
  end

  def test_custom_select
    order = Order.create!(date: Date.new(2017, 2, 28), amount: 56.72, customer_id: 42)

    results = OccamsRecord.
      query(Order.select('amount, id, date, customer_id').where(customer_id: 42)).run
    assert_equal 1, results.size
    assert_equal({
      amount: 56.72,
      id: order.id,
      date: Date.new(2017, 2, 28),
      customer_id: 42
    }, results[0].to_hash(symbolize_names: true, recursive: true))
  end

  def test_custom_select_with_casted_columns
    results = OccamsRecord.
      query(LineItem.select("order_id, SUM(amount) AS total_amount").group("order_id").order("total_amount")).
      run

    assert_equal 2, results.size
    assert_equal 100, results[0].total_amount
    assert_equal 520, results[1].total_amount
  end

  def test_loading_just_first
    log = []
    bob = OccamsRecord.query(User.where(username: "bob"), query_logger: log).first
    assert_equal "bob", bob.username
    assert_includes log.map { |x|
      normalize_sql x
    }, %q|root: SELECT users.* FROM users WHERE users.username = 'bob' LIMIT 1|
  end

  def test_loading_just_first_raises_exception
    log = []
    q = OccamsRecord.query(User.where(username: "nobody"), query_logger: log)
    assert_raises OccamsRecord::NotFound do
      q.first!
    end
    assert_includes log.map { |x|
      normalize_sql x
    }, %q|root: SELECT users.* FROM users WHERE users.username = 'nobody' LIMIT 1|
  end
end
