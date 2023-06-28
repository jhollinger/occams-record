require 'test_helper'

class EnumTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    Time.zone = "Eastern Time (US & Canada)"
  end

  def teardown
    DatabaseCleaner.clean
    Time.zone = nil
  end

  def test_empty_defined_enums
    assert_equal({}, Widget.defined_enums)
  end

  def test_defined_enums
    assert_equal({
      "status"=>{"pending"=>0, "active"=>1, "disabled"=>2}
    }, Common.defined_enums)
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
