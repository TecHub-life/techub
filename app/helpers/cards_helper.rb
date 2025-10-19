module CardsHelper
  # Build inline styles for background <img> based on normalized crop/zoom values.
  # fx/fy are floats in [0,1]; zoom is a float where 1.0 means no zoom.
  def bg_style_from(fx:, fy:, zoom:)
    require "bigdecimal"

    # Use BigDecimal to avoid binary floating rounding edge cases
    x_bd = (BigDecimal(clamp01(fx).to_s) * 100)
    y_bd = (BigDecimal(clamp01(fy).to_s) * 100)
    z_bd = (zoom.to_f.positive? ? BigDecimal(zoom.to_s) : BigDecimal("1.0"))

    x_str = x_bd.round(2).to_s("F")
    y_str = y_bd.round(2).to_s("F")
    z_str = format("%.3f", z_bd.round(3).to_f)

    "object-position: #{x_str}% #{y_str}%; transform: scale(#{z_str}); transform-origin: #{x_str}% #{y_str}%;"
  end

  private

  def clamp01(v)
    f = v.to_f
    return 0.0 if f.nan? || f.infinite?
    return 0.0 if f < 0.0
    return 1.0 if f > 1.0
    f
  end
end
