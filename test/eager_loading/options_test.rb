require 'test_helper'

class EagerLoadingOptionsTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_eager_load_as_a_custom_name
    widgets = OccamsRecord.
      query(Widget.order(:name)).
      eager_load(:category, as: :cat).
      run

    assert_equal [
      "Widget A: Foo",
      "Widget B: Foo",
      "Widget C: Foo",
      "Widget D: Bar",
      "Widget E: Bar",
      "Widget F: Bar",
      "Widget G: Bar",
    ], widgets.map { |w|
      "#{w.name}: #{w.cat.name}"
    }
  end

  def test_eager_load_a_custom_name_from_a_real_assoc
    widgets = OccamsRecord.
      query(Widget.order(:name)).
      eager_load(:cat, from: :category).
      run

    assert_equal [
      "Widget A: Foo",
      "Widget B: Foo",
      "Widget C: Foo",
      "Widget D: Bar",
      "Widget E: Bar",
      "Widget F: Bar",
      "Widget G: Bar",
    ], widgets.map { |w|
      "#{w.name}: #{w.cat.name}"
    }
  end

  def test_non_standard_pkey_name
    i1 = Icd10.create!(code: "W61.12XD", name: "Struck by macaw, subsequent encounter")
    HealthCondition.create!(name: "Hurt by bird", icd10_id: i1.id)

    res = OccamsRecord.
      query(HealthCondition.all).
      eager_load(:icd10).
      run

    assert_equal [
      "W61.12XD Hurt by bird",
    ], res.map { |x|
      "#{x.icd10.code} #{x.name}"
    }
  end
end
