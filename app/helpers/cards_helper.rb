module CardsHelper
  AVATAR_LIBRARY_PREFIXES = AppearanceLibrary::AVATAR_DIRS.keys.freeze
  SUPPORTING_ART_PREFIXES = AppearanceLibrary::SUPPORTING_ART_DIRS.keys.freeze
  BANNER_PREFIXES = AppearanceLibrary::BANNER_DIRS.keys.freeze

  SUPPORTING_ART_ASSET_KINDS = {
    "card" => "support_art_card",
    "og" => "support_art_og",
    "simple" => "support_art_simple",
    "square" => "support_art_square"
  }.freeze

  def avatar_image_url_for(profile, variant: :profile)
    id = resolved_avatar_id(profile, variant)
    provider, payload = AvatarSources.parse(id)

    case provider
    when :library
      path = payload.to_s
      if allowlisted_avatar_path?(path)
        return asset_path(path)
      else
        fallback = pick_from_library("avatars-1x1", profile.login)
        return asset_path(fallback) if fallback.present?
      end
    when :upload
      asset = profile.profile_assets.find_by(kind: payload.presence || "avatar_1x1")
      url = asset_public_or_local_url(profile, asset)
      return url if url.present?
      url = generated_upload_url(profile, payload.presence || "avatar_1x1")
      return url if url.present?
    when :github
      url = profile.avatar_url.to_s
      return url if url.present?
    else
      # Treat unknown providers as deterministic library picks
      path = deterministic_supporting_art_path(profile.login, :card)
      return asset_path(path) if path.present?
    end

    asset_path("android-chrome-512x512.jpg")
  rescue StandardError
    asset_path("android-chrome-512x512.jpg")
  end

  # Pick a supporting art image for the given aspect.
  def supporting_art_url_for(profile:, aspect: :og)
    return banner_image_url_for(profile) if aspect.to_sym == :banner

    variant = background_variant_for(aspect)
    choice = background_choice_for(profile, variant)
    return nil if choice == "color"

    if choice == "upload"
      asset_kind = SUPPORTING_ART_ASSET_KINDS[variant] || SUPPORTING_ART_ASSET_KINDS["card"]
      asset = profile.profile_assets.find_by(kind: asset_kind)
      url = asset_public_or_local_url(profile, asset)
      return url if url.present?
      url = generated_upload_url(profile, asset_kind)
      return url if url.present?
    end

    path = background_library_path(profile, variant)
    path ||= deterministic_supporting_art_path(profile.login, variant)
    return asset_path(path) if path.present?
    asset_path("techub-hero.jpg")
  rescue StandardError
    asset_path("techub-hero.jpg")
  end

  def banner_image_url_for(profile)
    case profile.banner_choice.to_s
    when "library"
      path = profile.banner_library_path.to_s
      return asset_path(path) if allowlisted_banner_path?(path)
    when "upload"
      asset = profile.profile_assets.find_by(kind: "banner_3x1")
      url = asset_public_or_local_url(profile, asset)
      return url if url.present?
      url = generated_upload_url(profile, "banner_3x1")
      return url if url.present?
    end

    default_banner = deterministic_banner_path(profile.login)
    default_banner ? asset_path(default_banner) : nil
  rescue StandardError
    nil
  end

  def bg_style_from(fx:, fy:, zoom:)
    require "bigdecimal"

    x_bd = (BigDecimal(clamp01(fx).to_s) * 100)
    y_bd = (BigDecimal(clamp01(fy).to_s) * 100)
    z_bd = (zoom.to_f.positive? ? BigDecimal(zoom.to_s) : BigDecimal("1.0"))

    x_str = x_bd.round(2).to_s("F")
    y_str = y_bd.round(2).to_s("F")
    z_str = format("%.3f", z_bd.round(3).to_f)

    "object-position: #{x_str}% #{y_str}%; transform: scale(#{z_str}); transform-origin: #{x_str}% #{y_str}%;"
  end

  private

  def resolved_avatar_id(profile, variant)
    card = profile.profile_card
    return card.avatar_source_id_for(variant) if card
    default_avatar_id(profile)
  end

  def default_avatar_id(profile)
    card = profile.profile_card
    if card&.avatar_choice.to_s == "ai"
      "upload:avatar_1x1"
    else
      "github"
    end
  end

  def allowlisted_avatar_path?(path)
    return false if path.to_s.blank?
    AVATAR_LIBRARY_PREFIXES.any? { |prefix| path.start_with?("#{prefix}/") }
  end

  def background_variant_for(aspect)
    case aspect.to_sym
    when :card then "card"
    when :simple then "simple"
    when :square then "square"
    else "og"
    end
  end

  def background_choice_for(profile, variant)
    card = profile.profile_card
    column = :"bg_choice_#{variant == 'square' ? 'simple' : variant}"
    value = card&.public_send(column).presence || "library"
    %w[library upload color].include?(value) ? value : "library"
  end

  def background_library_path(profile, variant)
    card = profile.profile_card
    entry = card&.bg_source_for(variant) || (variant == "square" ? card&.bg_source_for("simple") : nil)
    path = entry&.dig("path")
    allowlisted_supporting_art_path?(path) ? path : nil
  end

  def allowlisted_supporting_art_path?(path)
    return false if path.to_s.blank?
    SUPPORTING_ART_PREFIXES.any? { |prefix| path.start_with?("#{prefix}/") }
  end

  def allowlisted_banner_path?(path)
    return false if path.to_s.blank?
    BANNER_PREFIXES.any? { |prefix| path.start_with?("#{prefix}/") }
  end

  def deterministic_supporting_art_path(login, variant)
    dir = variant == "square" ? "supporting-art-1x1" : default_supporting_art_dir(variant)
    pick_from_library(dir, login)
  end

  def default_supporting_art_dir(variant)
    variant == "og" ? "supporting-art-1x1" : "supporting-art-1x1"
  end

  def deterministic_banner_path(login)
    pick_from_library("3x1-banners", login)
  end

  def pick_from_library(dir, login)
    base = Rails.root.join("app", "assets", "images", dir)
    files = Dir[base.join("*.{jpg,jpeg,png,webp}")].sort
    return nil if files.empty?
    idx = login.to_s.hash % files.length
    Pathname.new(files[idx]).relative_path_from(Rails.root.join("app", "assets", "images")).to_s
  rescue StandardError
    nil
  end

  def asset_public_or_local_url(profile, asset)
    return asset.public_url if asset&.public_url.present?
    local = asset&.local_path.to_s
    return local if local.start_with?("http")
    if local.start_with?("/")
      return local
    end
    generated_upload_url(profile, asset&.kind)
  end

  def generated_upload_url(profile, kind)
    safe_login = profile.login.to_s.downcase.gsub(/[^a-z0-9\-]/, "")
    return if safe_login.blank? || kind.to_s.blank?
    dir = Rails.root.join("public", "generated", safe_login)
    pattern = dir.join("#{kind}-custom*")
    file = Dir[pattern.to_s].sort.last
    return unless file
    "/generated/#{safe_login}/#{File.basename(file)}"
  rescue StandardError
    nil
  end

  def clamp01(v)
    f = v.to_f
    return 0.0 if f.nan? || f.infinite?
    return 0.0 if f < 0.0
    return 1.0 if f > 1.0
    f
  end
end
