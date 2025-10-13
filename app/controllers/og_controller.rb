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
      response.headers["Cache-Control"] = cache_header
      return redirect_to asset.public_url, allow_other_host: true
    end

    # Fallback to local filesystem under public/generated/<login>/
    base = Rails.root.join("public", "generated", login)
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

    # Not available yet — enqueue pipeline to generate assets
    Profiles::GeneratePipelineJob.perform_later(login)
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
