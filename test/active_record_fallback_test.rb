require 'test_helper'

class ActiveRecordFallbackTest < Minitest::Test
  include TestHelpers

  def setup
    DatabaseCleaner.start
    Time.zone = "Eastern Time (US & Canada)"
    @skip_strict_loading = ! defined? ActiveRecord::StrictLoadingViolationError
  end

  def teardown
    DatabaseCleaner.clean
    Time.zone = nil
  end

  def test_lazy_active_record_fallback_with_eager_loading
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A"), active_record_fallback: :lazy).
      eager_load(:detail).
      run

    deets = widgets[0].detail_with_category
    assert_equal "Foo - All about Widget A", deets
  end

  def test_strict_active_record_fallback_with_eager_loading
    return if @skip_strict_loading
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A"), active_record_fallback: :strict).
      eager_load(:category).
      eager_load(:detail).
      run

    deets = widgets[0].detail_with_category
    assert_equal "Foo - All about Widget A", deets
  end

  def test_lazy_active_record_fallback_without_eager_loading
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A"), active_record_fallback: :lazy).
      run

    deets = widgets[0].detail_with_category
    assert_equal "Foo - All about Widget A", deets
  end

  def test_strict_active_record_fallback_without_eager_loading
    return if @skip_strict_loading
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A"), active_record_fallback: :strict).
      run

    assert_raises ActiveRecord::StrictLoadingViolationError do
      deets = widgets[0].detail_with_category
      assert_equal "Foo - All about Widget A", deets
    end
  end

  def test_active_record_fallback_with_arg
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A"), active_record_fallback: :lazy).
      run

    deets = widgets[0].detail_with_category("foo")
    assert_equal "Foo - All about Widget A - foo", deets
  end

  def test_active_record_fallback_with_block
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A"), active_record_fallback: :lazy).
      run

    deets = widgets[0].detail_with_category { "bar" }
    assert_equal "Foo - All about Widget A - bar", deets
  end

  def test_active_record_fallback_with_arg_and_block
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A"), active_record_fallback: :lazy).
      run

    deets = widgets[0].detail_with_category("foo") { "bar" }
    assert_equal "Foo - All about Widget A - foo - bar", deets
  end

  def test_active_record_fallback_with_missing_method
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A")).
      eager_load(:category, active_record_fallback: :lazy).
      run

    e = assert_raises NoMethodError do
      widgets[0].category.invalid_method
    end
    assert_match(/Occams Record trace: root\.category.active_record_fallback\(Category\)/, e.message)
  end

  def test_active_record_fallback_with_missing_method_with_args
    widgets = OccamsRecord.
      query(Widget.where(name: "Widget A")).
      eager_load(:category, active_record_fallback: :lazy).
      run

    e = assert_raises NoMethodError do
      widgets[0].category.invalid_method(5)
    end
    assert_match(/Occams Record trace: root\.category.active_record_fallback\(Category\)/, e.message)
  end
end
