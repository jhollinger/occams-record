require 'test_helper'

class TypeConverterTest < Minitest::Test
  def test_converts_nil
    converter = MicroRecord::TypeConverter.new('PostgreSQL', ["name"], [:string])
    row = converter.to_hash [nil]
    assert_equal({"name" => nil}, row)
  end

  def test_converts_strings
    converter = MicroRecord::TypeConverter.new('PostgreSQL', ["name"], [:string])
    row = converter.to_hash ["Rando"]
    assert_equal({"name" => "Rando"}, row)
  end

  def test_converts_integers
    converter = MicroRecord::TypeConverter.new('PostgreSQL', ["id"], [:integer])
    row = converter.to_hash ["42"]
    assert_equal({"id" => 42}, row)
  end
end
