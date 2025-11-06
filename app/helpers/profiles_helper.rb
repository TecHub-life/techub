module ProfilesHelper
  PROFILE_CARD_VARIANT_CONFIG = [
    { kind: "card", label: "Main Card", dims: "1280×720", aspect: "16/9", usage: "Social posts", fallback: "card" },
    { kind: "card_pro", label: "Professional Card", dims: "1280×720", aspect: "16/9", usage: "Resumes & decks", fallback: "card_pro" },
    { kind: "og", label: "Open Graph", dims: "1200×630", aspect: "1200/630", usage: "Portfolio link previews", fallback: "og" },
    { kind: "og_pro", label: "Professional OG", dims: "1200×630", aspect: "1200/630", usage: "Professional link previews", fallback: "og_pro" },
    { kind: "simple", label: "Simple", dims: "1280×720", aspect: "16/9", usage: "Profiles & CVs", fallback: "simple" },
    { kind: "banner", label: "Banner", dims: "1500×500", aspect: "3/1", usage: "Header/banner", fallback: "banner" },
    { kind: "x_profile_400", label: "X Profile", dims: "400×400", aspect: "1/1", usage: "X avatar", fallback: "x_profile_400" },
    { kind: "ig_portrait_1080x1350", label: "Instagram Portrait", dims: "1080×1350", aspect: "4/5", usage: "Instagram post", fallback: "ig_portrait_1080x1350" },
    { kind: "fb_post_1080", label: "Facebook Post", dims: "1080×1080", aspect: "1/1", usage: "Facebook post", fallback: "fb_post_1080" },
    { kind: "x_header_1500x500", label: "X Header", dims: "1500×500", aspect: "3/1", usage: "X banner", fallback: "x_header_1500x500" },
    { kind: "x_feed_1600x900", label: "X Feed", dims: "1600×900", aspect: "16/9", usage: "X feed post", fallback: "x_feed_1600x900" },
    { kind: "ig_landscape_1080x566", label: "Instagram Landscape", dims: "1080×566", aspect: "540/283", usage: "Instagram landscape", fallback: "ig_landscape_1080x566" },
    { kind: "fb_cover_851x315", label: "Facebook Cover", dims: "851×315", aspect: "851/315", usage: "Facebook cover", fallback: "fb_cover_851x315" },
    { kind: "linkedin_cover_1584x396", label: "LinkedIn Cover", dims: "1584×396", aspect: "4/1", usage: "LinkedIn cover", fallback: "linkedin_cover_1584x396" },
    { kind: "youtube_cover_2560x1440", label: "YouTube Cover", dims: "2560×1440", aspect: "16/9", usage: "YouTube channel art", fallback: "youtube_cover_2560x1440" }
  ].freeze

  def profile_card_variants(profile)
    preferred = profile.preferred_og_kind
    PROFILE_CARD_VARIANT_CONFIG.map do |variant|
      url = profile_asset_url(profile, variant[:kind], fallback_basename: variant[:fallback])
      og_variant = Profile::OG_VARIANT_KINDS.include?(variant[:kind])
      variant.merge(
        url: url,
        absolute_url: profile_asset_url(profile, variant[:kind], fallback_basename: variant[:fallback], absolute: true),
        og_variant: og_variant,
        selected: og_variant && preferred == variant[:kind]
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
      # Rewrite third‑party storage hosts (e.g., DigitalOcean Spaces) to our CDN/custom domain.
      # When using region endpoints with path-style addressing, strip the bucket prefix from the path
      # because the CDN hostname already implies the bucket.
      begin
        cdn_endpoint = (Rails.application.credentials.dig(:do_spaces, :cdn_endpoint) rescue nil).presence || ENV["DO_SPACES_CDN_ENDPOINT"].to_s.presence
        if cdn_endpoint
          src = URI.parse(str)
          cdn = URI.parse(cdn_endpoint)
          if cdn.host.present?
            # Optionally remove bucket segment from the path when the source is a Spaces endpoint
            bucket = (ENV["DO_SPACES_BUCKET"].presence || (Rails.application.credentials.dig(:do_spaces, :bucket_name) rescue nil)).to_s
            if bucket.present?
              host = src.host.to_s
              # Match both origin and CDN Spaces hosts
              if host.end_with?(".digitaloceanspaces.com") || host.end_with?(".cdn.digitaloceanspaces.com")
                # If the path starts with /<bucket>/, drop that segment (virtual-host style under CDN)
                if src.path.to_s.start_with?("/#{bucket}/")
                  src.path = src.path.sub(%r{^/#{Regexp.escape(bucket)}/}, "/")
                end
              end
            end

            # Replace scheme/host/port
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
    if Dir.exist?(base)
      found = Dir[base.join("#{fallback_basename}*.{jpg,jpeg,png}").to_s].find do |candidate|
        (File.size?(candidate) || 0) > 1024
      end
      return found if found
    end

    # As a last resort for directory previews, use the OG endpoint which
    # will serve or trigger generation server-side if missing.
    fallback = fallback_basename.to_s
    if fallback == "og" || Profile::OG_VARIANT_KINDS.include?(fallback)
      variant_param = (fallback == "og") ? "" : "?variant=#{fallback}"
      return "/og/#{profile.login}.jpg#{variant_param}"
    end

    nil
  end
end
