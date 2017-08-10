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

  def test_nested
    log = []
    results = MicroRecord.
      query(Order.all, log).
      eager_load(:customer).
      eager_load(:items) {
        eager_load(:widget)
      }.
      run

    assert_equal [
      %q(SELECT "orders".* FROM "orders"),
      %q(SELECT "customers".* FROM "customers" WHERE "customers"."id" IN (846114006, 980204181)),
      %q(SELECT "order_items".* FROM "order_items" WHERE "order_items"."order_id" IN (683130438, 834596858)),
      %q(SELECT "widgets".* FROM "widgets" WHERE "widgets"."id" IN (417155790, 834596858, 112844655, 683130438, 802847325)),
    ], log

    assert_equal Order.all.map { |o|
      {
        id: o.id,
        date: o.date,
        amount: o.amount,
        customer_id: o.customer_id,
        customer: {
          id: o.customer.id,
          name: o.customer.name
        },
        items: o.items.map { |i|
          {
            id: i.id,
            order_id: i.order_id,
            widget_id: i.widget_id,
            amount: i.amount,
            widget: {
              id: i.widget.id,
              name: i.widget.name,
              category_id: i.widget.category_id
            }
          }
        }
      }
    }, results.map { |r| r.to_hash(symbolize_names: true) }
  end
end
