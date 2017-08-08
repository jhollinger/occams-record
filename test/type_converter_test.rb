require 'test_helper'

class TypeConverterTest < Minitest::Test
  def test_pg_converts_nil
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:string])
    assert_nil converter.convert(nil, 0)
    assert_nil converter.convert('NULL', 0)
  end

  def test_pg_converts_strings
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:string])
    assert_equal "Rando", converter.convert("Rando", 0)
  end

  def test_pg_converts_integers
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:integer])
    assert_equal 42, converter.convert("42", 0)
  end

  def test_pg_converts_float
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:float])
    assert_equal 42.5234123, converter.convert("42.5234123", 0)
  end

  def test_pg_converts_decimal
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:decimal])
    assert_equal BigDecimal.new("42.59"), converter.convert("42.59", 0)
  end

  def test_pg_converts_boolean
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:boolean])
    assert converter.convert('t', 0)
    refute converter.convert('f', 0)
    assert_nil converter.convert(nil, 0)
    assert_nil converter.convert('NULL', 0)
  end

  def test_pg_converts_date
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:date])
    assert_equal Date.new(2017, 2, 28), converter.convert("2017-02-28", 0)
  end

  def test_pg_converts_datetime
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:datetime])
    t = converter.convert("2017-07-06 15:01:51.058149", 0)
    assert_equal t.iso8601, Time.new(2017, 7, 6, 15, 1, 51).iso8601
  end

  def test_pg_converts_time
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:time])
    t = converter.convert("15:01:51", 0)
    assert_equal t.strftime("%H:%M:%S"), Time.new(2017, 7, 6, 15, 1, 51).strftime("%H:%M:%S")
  end

  def test_pg_converts_json
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:json])
    data = {'a' => 'A', '1k' => 100_000, 'events' => [
      {'foo' => 'Foo'}, {'bar' => 'Bar'}
    ]}
    assert_equal data, converter.convert(data.to_json, 0)
  end

  def test_pg_converts_hstore
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:hstore])
    assert_equal({"a" => "A", "b" => "B"}, converter.convert('"a"=>"A", "b"=>"B"', 0))
    # TODO correctly handle double quotes in keys and values
    #assert_equal({"a" => "A \"real\" test", "b\"b" => "B"}, converter.convert('"a"=>"A \"real\" test", "b\"b"=>"B"', 0))
  end

  def test_pg_converts_array
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:array])
    assert_equal(["foo", "bar"], converter.convert('{foo,bar}', 0))
    # TODO correctly handle commas in values
    #assert_equal(["foo", "bar"], converter.convert('{foo,"bar,s"}', 0))
  end

  def test_converts_row_to_hash
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:integer, :string], ["id", "name"])
    row = converter.to_hash ["42", "Rando"]
    assert_equal({"id" => 42, "name" => "Rando"}, row)
  end

  def test_converts_to_array
    converter = MicroRecord::TypeConverter.new('PostgreSQL', [:integer, :string])
    row = converter.to_array ["42", "Rando"]
    assert_equal([42, "Rando"], row)
  end
end
