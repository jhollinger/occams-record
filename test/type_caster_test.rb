require 'test_helper'

class TypeCasterTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    Time.zone = "Eastern Time (US & Canada)"
  end

  def teardown
    DatabaseCleaner.clean
    Time.zone = nil
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

    assert x.dec.is_a?(sqlite? ? Float : BigDecimal)
    assert x.day.is_a?(sqlite? ? String : Date)
    assert x.daytime.is_a?(sqlite? ? String : Time)
    assert_equal((
      if pg?
        true
      elsif (ar_version >= 6) || mysql?
        1
      else
        "t"
      end
    ), x.bool)
  end

  def test_pg_exotic_types
    if pg?
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

  def test_converts_datetimes_to_local_tz
    bob = OccamsRecord.query(User.where(id: users(:bob).id)).to_a.first
    assert_equal "2017-12-29T10:00:37-05:00", bob.created_at.iso8601
  end

  def test_enum_values
    conn = Common.connection
    conn.execute("INSERT INTO commons (status) VALUES (0)")
    conn.execute("INSERT INTO commons (status) VALUES (1)")
    conn.execute("INSERT INTO commons (status) VALUES (3)")

    results = OccamsRecord.query(Common.order(:status)).map(&:status)
    assert_equal [
      "pending",
      "active",
      nil
    ], results
  end

  def test_enum_values_with_pluck
    conn = Common.connection
    conn.execute("INSERT INTO commons (status) VALUES (0)")
    conn.execute("INSERT INTO commons (status) VALUES (1)")
    conn.execute("INSERT INTO commons (status) VALUES (3)")

    results = OccamsRecord.query(Common.order(:status)).pluck(:status)
    assert_equal [
      "pending",
      "active",
      nil
    ], results
  end

  def test_enum_values_with_multi_pluck
    conn = Common.connection
    conn.execute("INSERT INTO commons (id, status) VALUES (1, 0)")
    conn.execute("INSERT INTO commons (id, status) VALUES (2, 1)")
    conn.execute("INSERT INTO commons (id, status) VALUES (3, 3)")

    results = OccamsRecord.query(Common.order(:status)).pluck(:id, :status)
    assert_equal [
      [1, "pending"],
      [2, "active"],
      [3, nil]
    ], results
  end
end
