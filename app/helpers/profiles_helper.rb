module ProfilesHelper
  PROFILE_CARD_VARIANT_CONFIG = [
    { kind: "card", label: "Main Card", dims: "1280×720", aspect: "16/9", usage: "Social posts", fallback: "card" },
    { kind: "og", label: "Open Graph", dims: "1200×630", aspect: "1200/630", usage: "Portfolio link previews", fallback: "og" },
    { kind: "simple", label: "Simple", dims: "1280×720", aspect: "16/9", usage: "Profiles & CVs", fallback: "simple" },
    { kind: "banner", label: "Banner", dims: "1500×500", aspect: "3/1", usage: "Header/banner", fallback: "banner" },
    { kind: "x_profile_400", label: "X Profile", dims: "400×400", aspect: "1/1", usage: "X avatar", fallback: "x_profile_400" },
    { kind: "ig_portrait_1080x1350", label: "Instagram Portrait", dims: "1080×1350", aspect: "4/5", usage: "Instagram post", fallback: "ig_portrait_1080x1350" },
    { kind: "fb_post_1080", label: "Facebook Post", dims: "1080×1080", aspect: "1/1", usage: "Facebook post", fallback: "fb_post_1080" }
  ].freeze

  def profile_card_variants(profile)
    PROFILE_CARD_VARIANT_CONFIG.map do |variant|
      url = profile_asset_url(profile, variant[:kind], fallback_basename: variant[:fallback])
      variant.merge(
        url: url,
        absolute_url: profile_asset_url(profile, variant[:kind], fallback_basename: variant[:fallback], absolute: true)
      )
    end
  end

  def profile_asset_url(profile, kind, fallback_basename: nil, absolute: false)
    source = locate_profile_asset(profile, kind) || resolve_profile_fallback(profile, fallback_basename)
    url = canonical_profile_asset_url(source)
    absolute ? absolute_url_for(url) : url
  end

  def canonical_profile_asset_url(source)
    return if source.blank?

    str = source.to_s
    if str.start_with?("http://", "https://")
      # Rewrite third‑party storage hosts (e.g., DigitalOcean Spaces) to our CDN/custom domain
      begin
        cdn_endpoint = (Rails.application.credentials.dig(:do_spaces, :cdn_endpoint) rescue nil).presence || ENV["DO_SPACES_CDN_ENDPOINT"].to_s.presence
        if cdn_endpoint
          src = URI.parse(str)
          cdn = URI.parse(cdn_endpoint)
          # Only replace host/scheme if CDN host is different
          if cdn.host.present?
            src.scheme = cdn.scheme.presence || src.scheme
            src.host = cdn.host
            src.port = cdn.port if cdn.port && cdn.port != (cdn.scheme == "https" ? 443 : 80)
            return src.to_s
          end
        end
      rescue StandardError
        # If URI parsing fails, fall back to original string
      end
      return str
    end

    public_root = Rails.root.join("public")
    url_path = nil
    file_path = nil

    if str.start_with?(public_root.to_s)
      file_path = Pathname.new(str)
      url_path = "/#{file_path.relative_path_from(public_root)}"
    elsif str.start_with?("/")
      url_path = str
      candidate = public_root.join(str.delete_prefix("/"))
      file_path = candidate if candidate.exist?
    else
      clean = str.sub(%r{\A/+}, "")
      url_path = "/#{clean}"
      candidate = public_root.join(clean)
      file_path = candidate if candidate.exist?
    end

    if file_path&.exist?
      timestamp = file_path.mtime.to_i
      separator = url_path.include?("?") ? "&" : "?"
      url_path = "#{url_path}#{separator}v=#{timestamp}"
    end

    url_path
  end

  def render_markdown(content)
    return "" if content.blank?

    # Render markdown to HTML using GitHub-flavored markdown
    html = Commonmarker.to_html(content,
      plugins: { syntax_highlighter: nil },
      options: {
        parse: { smart: true },
        render: { unsafe: true } # Allow raw HTML (we'll sanitize it ourselves)
      }
    )

    # Sanitize HTML but allow safe tags including images
    sanitize(html, tags: %w[
      p br strong em b i u a img h1 h2 h3 h4 h5 h6
      ul ol li blockquote pre code hr div span
      table thead tbody tr th td
    ], attributes: %w[
      href src alt title class id width height
      align border cellpadding cellspacing
    ]).html_safe
  end

  private

  def locate_profile_asset(profile, kind)
    assets = profile.profile_assets
    assets.load
    asset = assets.detect { |record| record.kind == kind.to_s }
    return unless asset

    # Prefer uploaded/public URLs outright
    return asset.public_url.presence if asset.public_url.present?

    # Only use local_path if it resolves to a real file under /public
    local_path = asset.local_path.to_s
    return if local_path.blank?

    public_root = Rails.root.join("public")
    begin
      candidate = nil
      if local_path.start_with?(public_root.to_s)
        candidate = Pathname.new(local_path)
      elsif local_path.start_with?("/")
        # Treat absolute URL path as relative to /public (e.g., "/generated/loftwah/og.jpg")
        candidate = public_root.join(local_path.delete_prefix("/"))
      elsif (public_index = local_path.index("/public/"))
        cleaned = local_path[(public_index + 8)..-1]
        candidate = public_root.join(cleaned.to_s.sub(%r{\A/+}, ""))
      else
        candidate = public_root.join(local_path.sub(%r{\A/+}, ""))
      end

      if candidate && candidate.exist?
        return candidate.to_s
      end
    rescue StandardError
      # Ignore resolution errors and fall back to generated files
    end

    nil
  end

  def resolve_profile_fallback(profile, fallback_basename)
    return if fallback_basename.blank?

    base = Rails.root.join("public", "generated", profile.login)
    return unless Dir.exist?(base)

    Dir[base.join("#{fallback_basename}*.{jpg,jpeg,png}").to_s].find do |candidate|
      (File.size?(candidate) || 0) > 1024
    end
  end
end
