module CardsHelper
  # Build inline styles for background <img> based on normalized crop/zoom values.
  # fx/fy are floats in [0,1]; zoom is a float where 1.0 means no zoom.
  def bg_style_from(fx:, fy:, zoom:)
    x = clamp01(fx).to_f * 100.0
    y = clamp01(fy).to_f * 100.0
    z = (zoom.to_f.positive? ? zoom.to_f : 1.0)
    "object-position: #{x.round(2)}% #{y.round(2)}%; transform: scale(#{format('%.3f', z)}); transform-origin: #{x.round(2)}% #{y.round(2)}%;"
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
