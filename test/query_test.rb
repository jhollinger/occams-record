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
    assert_equal 0, q.eager_loaders.size
    refute_nil q.conn
  end

  def test_simple_query
    results = MicroRecord.query(Category.all.order('name')).run
    assert_equal %w(Bar Foo), results.map(&:name)
  end

  def test_custom_select
    order = Order.create!(date: Date.new(2017, 2, 28), amount: 56.72, customer_id: 42)

    results = MicroRecord.
      query(Order.select('amount, id, date, customer_id').where(customer_id: 42)).run
    assert_equal 1, results.size
    assert_equal({
      amount: 56.72,
      id: order.id,
      date: Date.new(2017, 2, 28),
      customer_id: 42
    }, results[0].to_hash(symbolize_names: true))
  end

  def test_belongs_to
    results = MicroRecord.
      query(Widget.all).
      eager_load(:category).
      run

    assert_equal Widget.all.map { |w|
      "#{w.name}: #{w.category.name}"
    }.sort, results.map { |w|
      "#{w.name}: #{w.category.name}"
    }.sort
  end

  def test_has_one
    results = MicroRecord.
      query(Widget.all).
      eager_load(:detail).
      run

    assert_equal Widget.all.map { |w|
      "#{w.name}: #{w.detail.text}"
    }.sort, results.map { |w|
      "#{w.name}: #{w.detail.text}"
    }.sort
  end

  def test_has_many
    results = MicroRecord.
      query(Order.all).
      eager_load(:items).
      run

    assert_equal Order.all.map { |o|
      {
        id: o.id,
        date: o.date,
        amount: o.amount,
        customer_id: o.customer_id,
        items: o.items.map { |i|
          {
            id: i.id,
            order_id: i.order_id,
            widget_id: i.widget_id,
            amount: i.amount
          }
        }
      }
    }, results.map { |r| r.to_hash(symbolize_names: true) }
  end
end
