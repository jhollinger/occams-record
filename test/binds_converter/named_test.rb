require 'test_helper'

class BindsConverterNamedTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    @converter = OccamsRecord::BindsConverter::Named
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_no_params
    sql = @converter.new("SELECT * FROM widgets", {}).to_s
    assert_equal "SELECT * FROM widgets", sql
  end

  def test_ruby_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = %{user_id} AND name IN (%{names})", {user_id: 5, names: %w[A B]}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %{user_id} AND name IN (%{names})", sql
  end

  def test_rails_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = :user_id AND name IN (:names)", {user_id: 5, names: %w[A B]}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %{user_id} AND name IN (%{names})", sql
  end

  def test_escapes_rails_params
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = \\:user_id AND name IN (:names)", {user_id: 5, names: %w[A B]}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = :user_id AND name IN (%{names})", sql
  end

  def test_param_at_end
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = :user_id AND name = :name", {user_id: 5, name: "A"}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %{user_id} AND name = %{name}", sql
  end

  def test_ignores_colon_followed_by_non_word
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = :user_id AND name LIKE 'foo:-'", {user_id: 5}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %{user_id} AND name LIKE 'foo:-'", sql
  end

  def test_ignores_postgresql_casts
    sql = @converter.new("SELECT (data::json ->> 'percent')::float FROM widgets", {}).to_s
    assert_equal "SELECT (data::json ->> 'percent')::float FROM widgets", sql
  end

  def test_ignores_colon_at_end
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = :user_id AND name LIKE 'foo:", {user_id: 5}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %{user_id} AND name LIKE 'foo:", sql
  end

  def test_missing_binds_raises
    e = assert_raises OccamsRecord::MissingBindValuesError do
      @converter.new("SELECT * FROM widgets WHERE user_id = :user_id AND name = :name AND age = :age", {user_id: 5}).to_s
    end
    assert_match(/Missing binds \(name, age\) in SELECT /, e.message)
  end

  def test_bind_false_positive_raises
    e = assert_raises OccamsRecord::MissingBindValuesError do
      @converter.new('SELECT * FROM widgets WHERE user_id = :user_id data @> {"ready":true}', {user_id: 5}).to_s
    end
    assert_match(/Missing binds \(true\) in SELECT /, e.message)
  end

  def test_too_many_binds_passes
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = :user_id", {user_id: 5, age: 42}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %{user_id}", sql
  end

  def test_stress
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = :a:a:a:a:a:a:a:a:a:a:a:a", {a: "A"}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %{a}%{a}%{a}%{a}%{a}%{a}%{a}%{a}%{a}%{a}%{a}%{a}", sql
  end

  def test_stress_with_spaces
    sql = @converter.new("SELECT * FROM widgets WHERE user_id = :a:a:a :a:a:a :a:a:a     :a:a:a ", {a: "A"}).to_s
    assert_equal "SELECT * FROM widgets WHERE user_id = %{a}%{a}%{a} %{a}%{a}%{a} %{a}%{a}%{a}     %{a}%{a}%{a} ", sql
  end
end
