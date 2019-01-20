require 'test_helper'

class UglyTest < Minitest::Test
  include TestHelpers

  def test_converts_to_an_active_record
    occams = OccamsRecord.
      query(Order.where(amount: 100)).
      eager_load(:customer, select: "id, 'Fakenameington' AS name").
      eager_load(:line_items, ->(q) { q.order "amount ASC" }).
      first
    active = OccamsRecord::Ugly.active_record Order, occams

    assert active.is_a?(Order)
    assert active.customer.is_a?(Customer)
    assert_equal "Fakenameington", active.customer.name
    assert active.line_items.all? { |x|
      x.is_a? LineItem
    }
    assert_equal [30, 70], active.line_items.map { |i| i.amount.to_i }
  end
end
