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

  def test_eager_load_with_default_scope
    log = []
    results = OccamsRecord.
      query(Order.all, query_logger: log).
      eager_load(:ordered_line_items, ->(q) { q.where('1 != 2') }).
      run

    assert_equal LineItem.count, results.map(&:ordered_line_items).flatten.size
    assert_includes log.map { |x|
      x.gsub(/\s+/, " ")
    }, %q(SELECT "line_items".* FROM "line_items" WHERE (1 != 2) AND "line_items"."order_id" IN (683130438, 834596858) ORDER BY item_type)
  end

  def test_eager_load_custom_select_from_proc
    log = []
    results = OccamsRecord.
      query(Order.all, query_logger: log).
      eager_load(:line_items, ->(q) { q.where('1 != 2') }).
      run

    assert_equal LineItem.count, results.map(&:line_items).flatten.size
    assert_includes log, %q(SELECT "line_items".* FROM "line_items" WHERE (1 != 2) AND "line_items"."order_id" IN (683130438, 834596858))
  end

  def test_eager_load_custom_select_from_string
    log = []
    results = OccamsRecord.
      query(Order.all, query_logger: log).
      eager_load(:line_items, select: "id, order_id").
      run

    assert_equal LineItem.count, results.map(&:line_items).flatten.size
    assert_includes log, %q(SELECT id, order_id FROM "line_items" WHERE "line_items"."order_id" IN (683130438, 834596858))
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

  def test_belongs_to_with_alt_name
    results = OccamsRecord.
      query(Widget.all).
      eager_load(:category, as: :cat).
      run

    assert_equal Widget.all.map { |w|
      "#{w.name}: #{w.category.name}"
    }.sort, results.map { |w|
      "#{w.name}: #{w.cat.name}"
    }.sort
  end

  def test_has_one
    results = OccamsRecord.
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
    results = OccamsRecord.
      query(Order.all).
      eager_load(:line_items).
      run

    assert_equal Order.all.map { |o|
      {
        id: o.id,
        date: o.date,
        amount: o.amount,
        customer_id: o.customer_id,
        line_items: o.line_items.map { |i|
          {
            id: i.id,
            order_id: i.order_id,
            item_id: i.item_id,
            item_type: i.item_type,
            category_id: i.item.category_id,
            amount: i.amount
          }
        }
      }
    }, results.map { |r| r.to_hash(symbolize_names: true, recursive: true) }
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
      %q(SELECT "categories".* FROM "categories"),
      %q(SELECT "widgets".* FROM "widgets" WHERE "widgets"."category_id" IN (208889123, 922717355)),
      %q(SELECT "widget_details".* FROM "widget_details" WHERE "widget_details"."widget_id" IN (112844655, 417155790, 683130438, 802847325, 834596858, 919808993)),
    ], log

    assert_equal Category.all.map { |c|
      {
        id: c.id,
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

  def test_nested_with_poly_belongs_to
    log = []
    results = OccamsRecord.
      query(Order.all, query_logger: log).
      eager_load(:customer).
      eager_load(:line_items) {
        eager_load(:item)
      }.
      run

    assert_equal [
      %q(SELECT "orders".* FROM "orders"),
      %q(SELECT "customers".* FROM "customers" WHERE "customers"."id" IN (846114006, 980204181)),
      %q(SELECT "line_items".* FROM "line_items" WHERE "line_items"."order_id" IN (683130438, 834596858)),
      %q(SELECT "widgets".* FROM "widgets" WHERE "widgets"."id" IN (417155790, 112844655, 683130438)),
      %q(SELECT "splines".* FROM "splines" WHERE "splines"."id" IN (683130438, 112844655)),
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
        line_items: o.line_items.map { |i|
          {
            id: i.id,
            order_id: i.order_id,
            item_id: i.item_id,
            item_type: i.item_type,
            category_id: i.item.category_id,
            amount: i.amount,
            item: {
              id: i.item.id,
              name: i.item.name,
              category_id: i.item.category_id
            }
          }
        }
      }
    }, results.map { |r| r.to_hash(symbolize_names: true, recursive: true) }
  end

  def test_poly_has_many
    results = OccamsRecord.
      query(Widget.all).
      eager_load(:line_items).
      run

    assert_equal Widget.count, results.size
    results.each do |widget|
      count = LineItem.where(item_id: widget.id, item_type: 'Widget').count
      assert_equal count, widget.line_items.size
      assert_equal count, widget.line_item_ids.size
    end
  end

  def test_has_and_belongs_to_many
    users = OccamsRecord.
      query(User.all).
      eager_load(:offices).
      run

    assert_equal 3, users.count
    bob = users.detect { |u| u.username == 'bob' }
    sue = users.detect { |u| u.username == 'sue' }
    craig = users.detect { |u| u.username == 'craig' }

    assert_equal %w(Bar Foo), bob.offices.map(&:name).sort
    assert_equal 2, bob.office_ids.size
    assert_equal %w(Bar Zorp), sue.offices.map(&:name).sort
    assert_equal %w(Foo), craig.offices.map(&:name).sort
  end

  def test_including_module
    mod_a, mod_b, mod_c = Module.new, Module.new, Module.new
    orders = OccamsRecord.
      query(Order.all, use: mod_a).
      eager_load(:line_items, use: mod_b) {
        eager_load(:item, use: mod_c)
      }.
      run

    assert_equal Order.count, orders.size
    orders.each do |order|
      assert order.is_a?(mod_a)
      refute order.is_a?(mod_b)
      refute order.is_a?(mod_c)

      assert order.line_items.any?
      refute order.line_items.all? { |line_item| line_item.is_a? mod_a }
      assert order.line_items.all? { |line_item| line_item.is_a? mod_b }
      refute order.line_items.all? { |line_item| line_item.is_a? mod_c }

      assert order.line_items.map(&:item).compact.any?
      refute order.line_items.all? { |line_item| line_item.item.is_a? mod_a }
      refute order.line_items.all? { |line_item| line_item.item.is_a? mod_b }
      assert order.line_items.all? { |line_item| line_item.item.is_a? mod_c }
    end
  end

  def test_including_multiple_modules
    mod_a, mod_b, mod_c = Module.new, Module.new, Module.new
    orders = OccamsRecord.
      query(Order.all, use: [mod_a, mod_b]).
      eager_load(:line_items, use: mod_b) {
        eager_load(:item, use: mod_c) {
          eager_load(:category, use: [mod_a, mod_c])
        }
      }.
      run

    assert_equal Order.count, orders.size
    orders.each do |order|
      assert order.is_a?(mod_a)
      assert order.is_a?(mod_b)
      refute order.is_a?(mod_c)

      assert order.line_items.any?
      refute order.line_items.all? { |line_item| line_item.is_a? mod_a }
      assert order.line_items.all? { |line_item| line_item.is_a? mod_b }
      refute order.line_items.all? { |line_item| line_item.is_a? mod_c }

      assert order.line_items.map(&:item).compact.any?
      refute order.line_items.all? { |line_item| line_item.item.is_a? mod_a }
      refute order.line_items.all? { |line_item| line_item.item.is_a? mod_b }
      assert order.line_items.all? { |line_item| line_item.item.is_a? mod_c }

      assert order.line_items.map(&:item).map(&:category).compact.any?
      assert order.line_items.all? { |line_item| line_item.item.category.is_a? mod_a }
      refute order.line_items.all? { |line_item| line_item.item.category.is_a? mod_b }
      assert order.line_items.all? { |line_item| line_item.item.category.is_a? mod_c }
    end
  end

  def test_converts_datetimes_to_local_tz
    bob = OccamsRecord.query(User.where(id: users(:bob).id)).to_a.first
    assert_equal "2017-12-29T10:00:37-05:00", bob.created_at.iso8601
  end

  def test_loading_just_first
    log = []
    bob = OccamsRecord.query(User.where(username: "bob"), query_logger: log).first
    assert_equal "bob", bob.username
    assert_includes log, %q|SELECT  "users".* FROM "users" WHERE "users"."username" = 'bob' LIMIT 1|
  end

  def test_loading_just_first_raises_exception
    log = []
    q = OccamsRecord.query(User.where(username: "nobody"), query_logger: log)
    assert_raises OccamsRecord::NotFound do
      q.first!
    end
    assert_includes log, %q|SELECT  "users".* FROM "users" WHERE "users"."username" = 'nobody' LIMIT 1|
  end

  def test_boolean_aliases
    offices(:bar).update_column(:active, true)
    offices(:foo).update_column(:active, false)
    offices(:zorp).update_column(:active, nil)

    offices = OccamsRecord.query(Office.order("name")).run
    assert_equal [true, false, false], offices.map(&:active?)
  end

  def test_raises_special_exception_for_missing_eager_load
    widget = OccamsRecord.query(Widget.limit(1)).run.first
    e = assert_raises OccamsRecord::MissingEagerLoadError do
      widget.category
    end
    assert_equal :category, e.name
    assert_equal "Widget", e.model_name
    assert_equal "Association 'category' is unavailable on Widget because it was not eager loaded!", e.message
  end

  def test_raises_special_exception_for_missing_column
    widget = OccamsRecord.query(Widget.select("id").limit(1)).run.first
    e = assert_raises OccamsRecord::MissingColumnError do
      widget.name
    end
    assert_equal :name, e.name
    assert_equal "Widget", e.model_name
    assert_equal "Column 'name' is unavailable on Widget because it was not included in the SELECT statement!", e.message
  end

  def test_raises_normal_method_missing_for_unknown_method
    widget = OccamsRecord.query(Widget.limit(1)).run.first
    assert_raises NoMethodError do
      widget.foo
    end
  end

  def test_to_s
    widget1 = OccamsRecord.query(Widget.all).first
    assert_equal %q(Widget{:id=>112844655, :name=>"Widget C", :category_id=>208889123}), widget1.to_s
  end

  def test_object_equality
    widget1 = OccamsRecord.query(Widget.all).first
    widget2 = OccamsRecord.query(Widget.all).first
    widget3 = OccamsRecord.query(Widget.all).run.last

    assert widget1 == widget2
    refute widget1 == widget3
    refute widget1 == OpenStruct.new(id: widget1.id)
  end

  def test_object_hash_access
    widget1 = OccamsRecord.query(Widget.all).eager_load(:category).first
    assert_equal widget1.name, widget1[:name]
    assert_equal widget1.name, widget1["name"]
    assert_equal widget1.category.name, widget1[:category][:name]
    assert_equal widget1.category.name, widget1["category"]["name"]
  end
end
