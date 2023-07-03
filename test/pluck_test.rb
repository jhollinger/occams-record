require 'test_helper'

class PluckTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_pluck_one
    names = OccamsRecord.query(Widget.order(:name)).pluck(:name)
    assert_equal Widget.order(:name).pluck(:name), names
  end

  def test_pluck_one_str
    names = OccamsRecord.query(Widget.order(:name)).pluck("name")
    assert_equal Widget.order(:name).pluck(:name), names
  end

  def test_pluck_one_str_with_func
    name_lengths = OccamsRecord.query(Widget.order(:name)).pluck("LENGTH(name)")
    assert_equal [8, 8, 8, 8, 8, 8, 8], name_lengths
  end

  def test_multi_mixed
    results = OccamsRecord.query(Widget.order(:name)).pluck(:name, "LENGTH(name)")
    assert_equal [
      ["Widget A", 8],
      ["Widget B", 8],
      ["Widget C", 8],
      ["Widget D", 8],
      ["Widget E", 8],
      ["Widget F", 8],
      ["Widget G", 8],
    ], results
  end

  def test_raw_pluck_one
    names = OccamsRecord.sql("SELECT name FROM widgets ORDER BY name", {}).pluck
    assert_equal Widget.order(:name).pluck(:name), names
  end

  def test_raw_pluck_one_str_with_func
    name_lengths = OccamsRecord.sql("SELECT LENGTH(name) FROM widgets ORDER BY name", {}).pluck
    assert_equal [8, 8, 8, 8, 8, 8, 8], name_lengths
  end

  def test_raw_pluck_one_str_with_func_as
    name_lengths = OccamsRecord.sql("SELECT LENGTH(name) AS len FROM widgets ORDER BY name", {}).pluck
    assert_equal [8, 8, 8, 8, 8, 8, 8], name_lengths
  end

  def test_raw_multi_mixed
    results = OccamsRecord.sql("SELECT name, LENGTH(name) FROM widgets ORDER BY name", {}).pluck
    assert_equal [
      ["Widget A", 8],
      ["Widget B", 8],
      ["Widget C", 8],
      ["Widget D", 8],
      ["Widget E", 8],
      ["Widget F", 8],
      ["Widget G", 8],
    ], results
  end
end
