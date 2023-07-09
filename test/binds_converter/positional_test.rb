require 'test_helper'

class BindsConverterPositionalTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    @converter = OccamsRecord::BindsConverter::Positional
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_no_params
    sql = @converter.new("SELECT * FROM widgets").to_s
    assert_equal "SELECT * FROM widgets", sql
  end

  def test_ruby_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = %s AND name IN (%s)").to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s AND name IN (%s)", sql
  end

  def test_rails_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ? AND name IN (?)").to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s AND name IN (%s)", sql
  end

  def test_escapes_rails_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = \\? AND name IN (?)").to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = ? AND name IN (%s)", sql
  end

  def test_param_at_end
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ? AND name = ?").to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s AND name = %s", sql
  end

  def test_stress
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ????????????").to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s%s%s%s%s%s%s%s%s%s%s%s", sql
  end

  def test_stress_with_spaces
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ??? ??? ???     ??? ").to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s%s%s %s%s%s %s%s%s     %s%s%s ", sql
  end
end
