module MotifsHelper
  # Returns a usable image URL for a motif with fallbacks in priority order:
  # 1) DB URL (uploaded/public)
  # 2) Asset pipeline image by convention: app/assets/images/{folder}/{slug}.{ext}
  # 3) Global placeholder: app/assets/images/android-chrome-512x512.jpg
  def motif_image_url(kind, slug, db_url = nil)
    return db_url if db_url.present?

    asset = motif_asset_path_for(kind, slug)
    return asset if asset.present?

    asset_path("android-chrome-512x512.jpg")
  end

  private

  def motif_asset_path_for(kind, slug)
    folder = (kind.to_s == "spirit_animal") ? "spirit-animals" : "archetypes"
    %w[png jpg jpeg webp].each do |ext|
      logical = File.join(folder, "#{slug}.#{ext}")
      begin
        return asset_path(logical) if asset_exists?(logical)
      rescue Propshaft::MissingAssetError
        # In dev, fall back to data: URL if the image exists on disk but propshaft can't resolve
        abs = Rails.root.join("app", "assets", "images", logical)
        return data_uri_for(abs) if abs.exist?
      end
    end
    nil
  end

  # Best-effort asset existence check that works in dev (Sprockets) and production (manifest)
  def asset_exists?(logical_path)
    env = Rails.application.assets
    # Sprockets
    if env && env.respond_to?(:find_asset)
      return env.find_asset(logical_path).present?
    end
    # Propshaft
    if env && env.respond_to?(:load_path)
      begin
        return env.load_path.find(logical_path).present?
      rescue StandardError
        # ignore
      end
    end
    # Manifest-based fallback (older Sprockets setups)
    manifest = Rails.application.assets_manifest rescue nil
    if manifest
      assets = manifest.respond_to?(:assets) ? manifest.assets : {}
      files  = manifest.respond_to?(:files)  ? manifest.files  : {}
      return assets[logical_path].present? || files[logical_path].present?
    end
    false
  rescue
    false
  end

  def data_uri_for(path)
    str = path.to_s
    return nil unless File.exist?(str)
    ext = File.extname(str).delete(".").downcase
    mime = case ext
    when "png" then "image/png"
    when "jpg", "jpeg" then "image/jpeg"
    when "webp" then "image/webp"
    else "application/octet-stream"
    end
    encoded = Base64.strict_encode64(File.binread(str))
    "data:#{mime};base64,#{encoded}"
  rescue StandardError
    nil
  end
end
