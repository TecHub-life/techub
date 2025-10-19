require "test_helper"

class CardsHelperTest < ActionView::TestCase
  include CardsHelper

  test "bg_style_from builds valid style string with clamped values" do
    style = bg_style_from(fx: 1.2, fy: -0.5, zoom: 0)
    # fx should clamp to 1.0 => 100%, fy to 0.0 => 0%, zoom default to 1.0
    assert_includes style, "object-position: 100.0% 0.0%"
    assert_includes style, "transform: scale(1.000)"
    assert_includes style, "transform-origin: 100.0% 0.0%"
  end

  test "bg_style_from formats percentages with two decimals and zoom with three" do
    style = bg_style_from(fx: 0.12345, fy: 0.98765, zoom: 1.2345)
    assert_includes style, "object-position: 12.35% 98.77%"
    assert_includes style, "transform: scale(1.235)"
  end
end
