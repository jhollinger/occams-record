require 'test_helper'

class RawQueryTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    @pg = !!(ActiveRecord::Base.connection.class.name =~ /postgres/i)
    @ar = ActiveRecord::VERSION::MAJOR
  end

  def teardown
    DatabaseCleaner.clean
    @pg = false
    @ar = nil
  end

  def test_initializes_correctly
    foo = categories :foo
    q = OccamsRecord::RawQuery.new(
      "SELECT * FROM widgets WHERE category_id = %{cat_id}",
      {cat_id: foo.id}
    )
    assert_equal "SELECT * FROM widgets WHERE category_id = %{cat_id}", q.sql
    assert_equal({cat_id: foo.id}, q.binds)
  end

  def test_simple_query
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id = %{cat_id} ORDER BY name",
        {cat_id: categories(:foo).id}
      ).
      run
    assert_equal ["Widget A", "Widget B", "Widget C"], results.map(&:name)
  end

  def test_simple_query_with_array_binds
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id IN (%{cat_id}) ORDER BY name",
        {cat_id: Category.pluck(:id)}
      ).
      run
    assert_equal ["Widget A", "Widget B", "Widget C", "Widget D", "Widget E", "Widget F", "Widget G"], results.map(&:name)
  end

  def test_eager_load
    results = OccamsRecord.
      sql(
        "SELECT * FROM widgets WHERE category_id = %{cat_id} ORDER BY name",
        {cat_id: categories(:foo).id}
      ).
      model(Widget).
      eager_load(:category).
      run
    assert_equal ["Widget A", "Widget B", "Widget C"], results.map(&:name)
    assert_equal ["Foo", "Foo", "Foo"], results.map { |r| r.category.name }
  end

  def test_find_in_batches
    batches = []
    OccamsRecord.
      sql("SELECT * FROM widgets ORDER BY name LIMIT %{batch_limit} OFFSET %{batch_offset}", {}).
      find_in_batches(batch_size: 2) { |batch|
        batches << batch
      }
    assert_equal [["Widget A", "Widget B"], ["Widget C", "Widget D"], ["Widget E", "Widget F"], ["Widget G"]], batches.map { |b|
      b.map(&:name)
    }
  end

  def test_find_in_batches_with_eager_load
    batches = []
    OccamsRecord.
      sql("SELECT * FROM line_items WHERE amount > %{amount} ORDER BY amount LIMIT %{batch_limit} OFFSET %{batch_offset}", {
        amount: 5,
      }).
      model(LineItem).
      eager_load(:item).
      find_in_batches(batch_size: 2) { |batch|
        batches << batch
      }
    assert_equal [2, 2, 1], batches.map(&:size)
    assert_equal [[20, 30], [70, 200], [300]], batches.map { |b|
      b.map(&:amount)
    }
    assert_equal [["Spline C", "Widget A"], ["Spline A", "Widget C"], ["Widget D"]], batches.map { |b|
      b.map(&:item).map(&:name)
    }
  end

  def test_common_types
    Common.create!({
      name: "asdf",
      desc: "sdiuj aispduhfa sdf",
      int: 42,
      flt: 4.2,
      dec: 100.5,
      day: Date.new(2020, 2, 3),
      daytime: Time.local(2020, 2, 3, 10, 30, 0),
      bool: true,
    })

    x =
      OccamsRecord
        .sql("SELECT * FROM commons ORDER BY name", {})
        .first

    assert x.id.is_a? Integer
    assert x.name.is_a? String
    assert x.desc.is_a? String
    assert x.int.is_a? Integer
    assert x.flt.is_a? Float
  end

  def test_advanced_types
    Common.create!({
      name: "asdf",
      desc: "sdiuj aispduhfa sdf",
      int: 42,
      flt: 4.2,
      dec: 100.5,
      day: Date.new(2020, 2, 3),
      daytime: Time.local(2020, 2, 3, 10, 30, 0),
      bool: true,
    })

    x =
      OccamsRecord
        .sql("SELECT * FROM commons ORDER BY name", {})
        .first

    assert x.dec.is_a?(@pg ? BigDecimal : Float)
    assert x.day.is_a?(@pg ? Date : String)
    assert x.daytime.is_a?(@pg ? Time : String)
    assert_equal((
      if @pg
        true
      elsif @ar >= 6
        1
      else
        "t"
      end
    ), x.bool)
  end

  def test_pg_exotic_types
    if @pg
      Exotic.create!({
        data1: {foo: "foo", num: 5, q: false},
        data2: {foo: "foo", num: 5, q: false},
        data3: {foo: "foo", num: 5, q: false},
        tags: ["foo", "bar"],
      })

      x = OccamsRecord
        .sql("SELECT * FROM exotics", {})
        .first

      assert x.id.is_a?(String)
      assert_equal({"foo" => "foo", "num" => 5, "q" => false}, x.data1)
      assert_equal({"foo" => "foo", "num" => 5, "q" => false}, x.data2)
      assert_equal({"foo" => "foo", "num" => "5", "q" => "false"}, x.data3)
      assert_equal ["foo", "bar"], x.tags
    end
  end
end
