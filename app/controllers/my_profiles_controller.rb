class MyProfilesController < ApplicationController
  before_action :require_login
  before_action :load_profile_and_authorize, only: [ :settings, :update_settings, :regenerate, :regenerate_ai, :upload_asset, :destroy ]

  def index
    uid = current_user&.id || session[:current_user_id]
    if uid.blank?
      return redirect_to auth_github_path, alert: "Please sign in with GitHub"
    end
    @profiles = Profile.joins(:profile_ownerships).where(profile_ownerships: { user_id: uid }).order(:login)
  end

  def settings
    # @profile loaded by before_action
    @asset_og = @profile.profile_assets.find_by(kind: "og")
    @asset_card = @profile.profile_assets.find_by(kind: "card")
    @asset_simple = @profile.profile_assets.find_by(kind: "simple")

    # For UI: compute AI regen availability
    @ai_regen_available_at = (@profile.last_ai_regenerated_at || Time.at(0)) + 7.days
  end

  def update_settings
    record = @profile.profile_card || @profile.build_profile_card
    # Allow: ai | default | color
    permitted = params.permit(:bg_choice_card, :bg_color_card, :bg_choice_og, :bg_color_og, :bg_choice_simple, :bg_color_simple)
    record.assign_attributes(permitted.to_h)
    if record.save
      redirect_to my_profile_settings_path(username: @profile.login), notice: "Settings updated"
    else
      redirect_to my_profile_settings_path(username: @profile.login), alert: "Could not save settings"
    end
  end

  def regenerate
    # Re-capture non-AI screenshots and optimize only
    Profiles::GeneratePipelineJob.perform_later(@profile.login, ai: false)
    @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
    redirect_to my_profile_settings_path(username: @profile.login), notice: "Re-capture queued for @#{@profile.login} (no AI cost)"
  end

  def regenerate_ai
    # Enforce weekly AI regeneration limits per profile
    next_allowed = (@profile.last_ai_regenerated_at || Time.at(0)) + 7.days
    if Time.current < next_allowed
      wait_h = ((next_allowed - Time.current) / 3600.0).ceil
      return redirect_to my_profile_settings_path(username: @profile.login), alert: "AI regeneration available in ~#{wait_h}h"
    end

    Profiles::GeneratePipelineJob.perform_later(@profile.login, ai: true)
    @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil, last_ai_regenerated_at: Time.current)
    redirect_to my_profile_settings_path(username: @profile.login), notice: "AI regeneration queued for @#{@profile.login} (weekly limit)"
  end

  def upload_asset
    kind = params[:kind].to_s
    file = params[:file]
    allowed = %w[og card simple avatar_3x1]
    unless allowed.include?(kind)
      return redirect_to my_profile_settings_path(username: @profile.login), alert: "Unsupported kind"
    end
    unless file.respond_to?(:path)
      return redirect_to my_profile_settings_path(username: @profile.login), alert: "No file uploaded"
    end

    begin
      # Upload to Active Storage / Spaces if enabled
      content_type = file.content_type.presence || "application/octet-stream"
      filename = "#{@profile.login}-#{kind}-custom#{File.extname(file.original_filename.to_s)}"
      up = Storage::ActiveStorageUploadService.call(path: file.path, content_type: content_type, filename: filename)
      return redirect_to my_profile_settings_path(username: @profile.login), alert: (up.error&.message || "Upload failed") if up.failure?

      public_url = up.value[:public_url]

      # Best-effort: copy to public/generated for local fallback
      begin
        dir = Rails.root.join("public", "generated", @profile.login)
        FileUtils.mkdir_p(dir)
        target = dir.join("#{kind}-custom#{File.extname(filename)}")
        FileUtils.cp(file.path, target)
      rescue StandardError
        # ignore copy failures
      end

      # Record/overwrite canonical asset row
      rec = ProfileAssets::RecordService.call(
        profile: @profile,
        kind: kind,
        local_path: "uploaded:#{Time.current.to_i}:#{filename}",
        public_url: public_url,
        mime_type: content_type,
        provider: "upload"
      )
      if rec.failure?
        return redirect_to my_profile_settings_path(username: @profile.login), alert: (rec.error&.message || "Save failed")
      end

      redirect_to my_profile_settings_path(username: @profile.login), notice: "Updated #{kind.humanize} image"
    rescue StandardError => e
      redirect_to my_profile_settings_path(username: @profile.login), alert: e.message
    end
  end

  def destroy
    ownership = ProfileOwnership.find_by(user_id: current_user.id, profile_id: @profile.id)
    return redirect_to my_profiles_path, alert: "You do not own this profile" unless ownership
    ownership.destroy!
    redirect_to my_profiles_path, notice: "Removed @#{@profile.login} from your profiles"
  end

  private

  def require_login
    @current_user ||= User.find_by(id: session[:current_user_id]) if @current_user.nil? && session[:current_user_id].present?
    return if current_user.present?
    redirect_to auth_github_path, alert: "Please sign in with GitHub"
  end

  def load_profile_and_authorize
    @profile = Profile.for_login(params[:username]).first
    return redirect_to my_profiles_path, alert: "Profile not found" unless @profile
    owner_id = current_user&.id || session[:current_user_id]
    unless ProfileOwnership.exists?(user_id: owner_id, profile_id: @profile.id)
      redirect_to my_profiles_path, alert: "You do not own this profile"
    end
  end
end
