module CardsHelper
  # Pick a deterministic supporting-art image from app/assets based on login and desired aspect.
  # aspect: :card (16x9), :og (16x9), :simple (16x9), :banner (3x1), :square (1x1)
  def supporting_art_url_for(login:, aspect: :og)
    base = Rails.root.join("app", "assets", "images")
    # Map aspects to a backing folder; use 1x1 library unless we later introduce 16x9/3x1 sets
    dir_name = case aspect
    when :banner then "supporting-art-1x1" # temporary: reuse 1x1 until 3x1 library exists
    else "supporting-art-1x1"
    end
    dir = base.join(dir_name)
    files = Dir[dir.join("*.{jpg,jpeg,png}").to_s]
    return asset_path("default-card.jpg") if files.empty?
    idx = login.to_s.hash % files.length
    rel = Pathname.new(files[idx]).relative_path_from(base).to_s
    asset_path(rel)
  rescue StandardError
    asset_path("default-card.jpg")
  end

  # Centralized avatar URL selection: defaults to GitHub avatar unless AI is opted-in and present.
  # Also allow using our pre-defined avatars library (avatars-1x1) when avatar_choice == 'ai' but no AI asset exists.
  def avatar_image_url_for(profile)
    choice = profile.profile_card&.avatar_choice || "real"
    # If AI art is not opted-in, force real
    choice = "real" unless profile.ai_art_opt_in

    if choice == "ai"
      ai_avatar = profile.profile_assets.find_by(kind: "avatar_1x1")
      return ai_avatar.public_url if ai_avatar&.public_url.present?
      # Fallback to our avatars library deterministically by login
      base = Rails.root.join("app", "assets", "images", "avatars-1x1")
      files = Dir[base.join("*.{jpg,jpeg,png}").to_s]
      if files.any?
        idx = profile.login.to_s.hash % files.length
        rel = Pathname.new(files[idx]).relative_path_from(Rails.root.join("app", "assets", "images")).to_s
        return asset_path(rel)
      end
    end

    profile.avatar_url
  rescue StandardError
    profile.avatar_url
  end

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
