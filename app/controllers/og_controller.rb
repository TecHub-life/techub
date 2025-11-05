class OgController < ApplicationController
  # Serves or redirects to a profile's OG image.
  # - If a CDN/public URL exists in ProfileAssets, 302 redirect (allows off-host).
  # - Else if local file exists, send the file with appropriate content type.
  # - Else enqueue the pipeline and return 202 Accepted JSON to indicate generation in progress.
  def show
    login = params[:login].to_s.downcase
    format = params[:format].presence || "jpg"

    profile = Profile.for_login(login).first
    return head :not_found unless profile

    # Prefer recorded asset row
    asset = profile.profile_assets.find_by(kind: "og")
    if asset&.public_url.present?
      begin
        url = URI.parse(asset.public_url.to_s)
        allowed = ENV["ASSET_REDIRECT_ALLOWED_HOSTS"].to_s.split(/[,\s]+/).reject(&:blank?)
        if url.is_a?(URI::HTTP) && url.host.present? && allowed.include?(url.host)
          response.headers["Cache-Control"] = cache_header
          return redirect_to url.to_s, allow_other_host: true
        end
      rescue URI::InvalidURIError
        # fall through to local fallback
      end
    end

    # Fallback to local filesystem under public/generated/<login>/
    # Sanitize login for filesystem usage to prevent path traversal
    safe_login = profile.login.to_s.downcase.gsub(/[^a-z0-9\-]/, "")
    return head :bad_request if safe_login.blank?
    base = Rails.root.join("public", "generated", safe_login)
    path = nil
    if format.to_s.downcase == "jpg"
      path = base.join("og.jpg")
      path = base.join("og.jpeg") unless File.exist?(path)
    end
    path ||= base.join("og.png")

    if File.exist?(path)
      response.headers["Cache-Control"] = cache_header
      mime = mime_for(path)
      return send_file path, type: mime, disposition: "inline"
    end

    # Not available yet — enqueue pipeline to generate assets without generating new images
    Profiles::GeneratePipelineJob.perform_later(login, trigger_source: "og_controller")
    render json: { status: "generating", login: login }, status: :accepted
  end

  private

  def cache_header
    # One year; assets are immutable once generated
    "public, max-age=31536000"
  end

  def mime_for(path)
    case File.extname(path.to_s).downcase
    when ".jpg", ".jpeg" then "image/jpeg"
    else "image/png"
    end
  end
end
