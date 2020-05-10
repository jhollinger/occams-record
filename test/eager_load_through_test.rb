require 'test_helper'

class EagerLoadThroughTest < Minitest::Test
  include TestHelpers

  #
  # NO optimizer
  #
  def test_eager_load_through_belongs_to_belongs_to_with_no_optimizer
    log = []
    widget_details = OccamsRecord.
      query(WidgetDetail.order(:text), query_logger: log).
      eager_load(:category, optimizer: :none).
      run

    assert_equal [
      %(SELECT "widget_details".* FROM "widget_details" ORDER BY "widget_details"."text" ASC),
      %(SELECT "widgets".* FROM "widgets" WHERE "widgets"."id" IN (30677878, 112844655, 417155790, 683130438, 802847325, 834596858, 919808993)),
      %(SELECT "categories".* FROM "categories" WHERE "categories"."id" IN (208889123, 922717355)),
    ], log.map { |x| x.gsub(/\s+/, " ") }

    assert_equal [
      "All about Widget A: Foo",
      "All about Widget B: Foo",
      "All about Widget C: Foo",
      "All about Widget D: Bar",
      "All about Widget E: Bar",
      "All about Widget F: Bar",
      "Make it an uneven number: Bar",
    ], widget_details.map { |d|
      "#{d.text}: #{d.category.name}"
    }
  end

  def test_eager_load_through_has_many_has_many_with_no_optimizer
    log = []
    customers = OccamsRecord.
      query(Customer.order(:name), query_logger: log).
      eager_load(:line_items, optimizer: :none).
      run

    assert_equal [
      %(SELECT "customers".* FROM "customers" ORDER BY "customers"."name" ASC),
      %(SELECT "orders".* FROM "orders" WHERE "orders"."customer_id" IN (846114006, 980204181)),
      %(SELECT "line_items".* FROM "line_items" WHERE "line_items"."order_id" IN (683130438, 834596858)),
    ], log.map { |x| x.gsub(/\s+/, " ") }

    assert_equal [
      "Jane: 3",
      "Jon: 2",
    ], customers.map { |c|
      "#{c.name}: #{c.line_items.size}"
    }
  end

  def test_eager_load_through_has_many_has_many_belongs_to_with_no_optimizer
    log = []
    customers = OccamsRecord.
      query(Customer.order(:name), query_logger: log).
      eager_load(:categories, optimizer: :none).
      run

    assert_equal [
      %(SELECT "customers".* FROM "customers" ORDER BY "customers"."name" ASC),
      %(SELECT "orders".* FROM "orders" WHERE "orders"."customer_id" IN (846114006, 980204181)),
      %(SELECT "line_items".* FROM "line_items" WHERE "line_items"."order_id" IN (683130438, 834596858)),
      %(SELECT "categories".* FROM "categories" WHERE "categories"."id" IN (208889123, 922717355)),
    ], log.map { |x| x.gsub(/\s+/, " ") }

    assert_equal [
      "Jane: Bar, Foo",
      "Jon: Foo",
    ], customers.map { |c|
      cats = c.categories.map(&:name).sort
      "#{c.name}: #{cats.join(', ')}"
    }
  end

  #
  # SELECT optimizer
  #

  def test_eager_load_through_belongs_to_belongs_to_with_select_optimizer
    log = []
    widget_details = OccamsRecord.
      query(WidgetDetail.order(:text), query_logger: log).
      eager_load(:category, optimizer: :select).
      run

    assert_equal [
      %(SELECT "widget_details".* FROM "widget_details" ORDER BY "widget_details"."text" ASC),
      %(SELECT id, category_id FROM "widgets" WHERE "widgets"."id" IN (30677878, 112844655, 417155790, 683130438, 802847325, 834596858, 919808993)),
      %(SELECT "categories".* FROM "categories" WHERE "categories"."id" IN (208889123, 922717355)),
    ], log.map { |x| x.gsub(/\s+/, " ") }

    assert_equal [
      "All about Widget A: Foo",
      "All about Widget B: Foo",
      "All about Widget C: Foo",
      "All about Widget D: Bar",
      "All about Widget E: Bar",
      "All about Widget F: Bar",
      "Make it an uneven number: Bar",
    ], widget_details.map { |d|
      "#{d.text}: #{d.category.name}"
    }
  end

  def test_eager_load_through_has_many_has_many_with_select_optimizer
    log = []
    customers = OccamsRecord.
      query(Customer.order(:name), query_logger: log).
      eager_load(:line_items, optimizer: :select).
      run

    assert_equal [
      %(SELECT "customers".* FROM "customers" ORDER BY "customers"."name" ASC),
      %(SELECT id, customer_id FROM "orders" WHERE "orders"."customer_id" IN (846114006, 980204181)),
      %(SELECT "line_items".* FROM "line_items" WHERE "line_items"."order_id" IN (683130438, 834596858)),
    ], log.map { |x| x.gsub(/\s+/, " ") }

    assert_equal [
      "Jane: 3",
      "Jon: 2",
    ], customers.map { |c|
      "#{c.name}: #{c.line_items.size}"
    }
  end

  def test_eager_load_through_has_many_has_many_belongs_to_with_select_optimizer
    log = []
    customers = OccamsRecord.
      query(Customer.order(:name), query_logger: log).
      eager_load(:categories, optimizer: :select).
      run

    assert_equal [
      %(SELECT "customers".* FROM "customers" ORDER BY "customers"."name" ASC),
      %(SELECT id, customer_id FROM "orders" WHERE "orders"."customer_id" IN (846114006, 980204181)),
      %(SELECT id, order_id, category_id FROM "line_items" WHERE "line_items"."order_id" IN (683130438, 834596858)),
      %(SELECT "categories".* FROM "categories" WHERE "categories"."id" IN (208889123, 922717355)),
    ], log.map { |x| x.gsub(/\s+/, " ") }

    assert_equal [
      "Jane: Bar, Foo",
      "Jon: Foo",
    ], customers.map { |c|
      cats = c.categories.map(&:name).sort
      "#{c.name}: #{cats.join(', ')}"
    }
  end

  def test_eager_load_using_custom_name
    customers = OccamsRecord.
      query(Customer.order(:name)).
      eager_load(:categories, as: :cats).
      run

    assert_equal [
      "Jane: Bar, Foo",
      "Jon: Foo",
    ], customers.map { |c|
      cats = c.cats.map(&:name).sort
      "#{c.name}: #{cats.join(', ')}"
    }
  end

  def test_eager_load_through_name_collision_a
    widget_details = OccamsRecord.
      query(WidgetDetail.all).
      # explicity load :widget (with all fields)
      eager_load(:widget).
      # :widget is implicitly loaded b/c :category is :through :widget (but only fkeys are loaded)
      eager_load(:category).
      first

    widget = widget_details.widget
    refute widget.respond_to?(:name)
  end

  def test_eager_load_through_name_collision_b
    widget_details = OccamsRecord.
      query(WidgetDetail.all).
      # :widget is implicitly loaded b/c :category is :through :widget (but only fkeys are loaded)
      eager_load(:category).
      # explicity load :widget (with all fields)
      eager_load(:widget).
      first

    widget = widget_details.widget
    assert widget.respond_to?(:name)
  end
end
