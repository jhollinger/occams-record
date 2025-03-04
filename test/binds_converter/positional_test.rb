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
    sql = @converter.new("SELECT * FROM widgets", []).to_s
    assert_equal "SELECT * FROM widgets", sql
  end

  def test_ruby_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = %s AND name IN (%s)", [5, %w[foo bar]]).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s AND name IN (%s)", sql
  end

  def test_rails_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ? AND name IN (?)", [5, %w[foo bar]]).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s AND name IN (%s)", sql
  end

  def test_escapes_rails_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = \\? AND name IN (?)", [5, %w[foo bar]]).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = ? AND name IN (%s)", sql
  end

  def test_param_at_end
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ? AND name = ?", [5, "foo"]).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s AND name = %s", sql
  end

  def test_missing_binds_raises
    e = assert_raises OccamsRecord::MissingBindValuesError do
      @converter.new("SELECT * FROM widgets WHERE user_id = ? AND name = ?", [5]).to_s
    end
    assert_match /Missing binds \(1\) in SELECT /, e.message
  end

  def test_too_many_binds_passes
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ? AND name = ?", [5, "foo", "bar"]).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s AND name = %s", sql
  end

  def test_stress
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ????????????", [5] * 12).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s%s%s%s%s%s%s%s%s%s%s%s", sql
  end

  def test_stress_with_spaces
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = ??? ??? ???     ??? ", [5] * 12).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %s%s%s %s%s%s %s%s%s     %s%s%s ", sql
  end
end
