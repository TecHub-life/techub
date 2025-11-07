module MyProfilesHelper
  def avatar_mode_for(profile, variant)
    normalized = variant.to_s
    id = avatar_source_id(profile, variant)
    return "inherit" if id.nil? && normalized != "default"

    provider, = AvatarSources.parse(id || "github")
    case provider
    when :library then "library"
    when :upload then "upload"
    else "github"
    end
  end

  def avatar_library_path_for(profile, variant)
    id = avatar_source_id(profile, variant)
    return nil unless id.to_s.start_with?("library:")
    id.sub(/\Alibrary:/, "")
  end

  def bg_library_path_for(profile, variant)
    card = profile.profile_card
    sources = card&.bg_sources_hash || {}
    entry = sources[variant.to_s]
    entry ||= sources["simple"] if variant.to_s == "square"
    entry&.dig("path")
  end

  def banner_library_path_for(profile)
    profile.banner_library_path
  end

  def profile_uploaded_asset_url(profile, kind)
    asset = profile.profile_assets.find_by(kind: kind)
    return asset.public_url if asset&.public_url.present?
    generated_asset_url(profile, kind)
  end

  private

  def avatar_source_id(profile, variant)
    card = profile.profile_card
    return nil unless card
    key = variant.to_s
    id = card.avatar_source_id_for(key, fallback: false)
    return id if id.present?

    if key != "default"
      nil
    else
      card.avatar_source_id_for("default")
    end
  end

  def generated_asset_url(profile, kind)
    safe_login = profile.login.to_s.downcase.gsub(/[^a-z0-9\-]/, "")
    return if safe_login.blank?
    dir = Rails.root.join("public", "generated", safe_login)
    pattern = dir.join("#{kind}-custom*")
    file = Dir[pattern.to_s].sort.last
    return unless file
    "/generated/#{safe_login}/#{File.basename(file)}"
  rescue StandardError
    nil
  end
end
