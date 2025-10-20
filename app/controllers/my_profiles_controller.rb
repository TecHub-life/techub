class MyProfilesController < ApplicationController
  before_action :require_login
  before_action :load_profile_and_authorize, only: [ :settings, :update_settings, :regenerate, :regenerate_ai, :upload_asset, :destroy ]

  def index
    uid = current_user&.id || session[:current_user_id]
    if uid.blank?
      return redirect_to auth_github_path, alert: "Please sign in with GitHub"
    end
    # Only show profiles the user actually owns to avoid confusion with past submissions
    @profiles = Profile
      .joins(:profile_ownerships)
      .where(profile_ownerships: { user_id: uid, is_owner: true })
      .order(:login)
    # Ownership cap info for UI (user can own up to cap)
    cap = (ENV["PROFILE_OWNERSHIP_CAP"].presence || 5).to_i
    @ownership_cap = cap
    @ownership_count = User.find_by(id: uid)&.profile_ownerships&.where(is_owner: true)&.count.to_i
    @ownership_remaining = [ cap - @ownership_count, 0 ].max

    # One-time notices for removed links (when rightful owner claimed)
    deliveries = NotificationDelivery.where(user_id: uid, event: "ownership_link_removed", subject_type: "Profile")
    removed_profile_ids = deliveries.pluck(:subject_id).uniq
    if removed_profile_ids.any?
      removed_profiles = Profile.where(id: removed_profile_ids).index_by(&:id)
      @ownership_removed_notices = removed_profile_ids.map do |pid|
        p = removed_profiles[pid]
        next unless p
        "Your link to @#{p.login} was removed when @#{p.login} claimed ownership."
      end.compact
      # Best-effort: clear deliveries so the banner shows once
      deliveries.delete_all
    else
      @ownership_removed_notices = []
    end
  end

  def settings
    # @profile loaded by before_action
    assets = @profile.profile_assets.where(kind: %w[og card simple]).index_by(&:kind)
    @asset_og = assets["og"]
    @asset_card = assets["card"]
    @asset_simple = assets["simple"]

    # For UI: compute AI regen availability
    @ai_regen_available_at = (@profile.last_ai_regenerated_at || Time.at(0)) + 7.days

    # Social targets for preview (label + aspect ratio class)
    @social_targets = [
      { kind: "x_profile_400", label: "X Profile 400×400", aspect: "1/1", hint: "Profile picture • Round crop" },
      { kind: "x_header_1500x500", label: "X Header 1500×500", aspect: "3/1", hint: "Profile header banner" },
      { kind: "x_feed_1600x900", label: "X Feed 1600×900", aspect: "16/9", hint: "Landscape post" },
      { kind: "ig_square_1080", label: "Instagram 1080×1080", aspect: "1/1", hint: "Square post" },
      { kind: "ig_portrait_1080x1350", label: "Instagram 1080×1350", aspect: "4/5", hint: "Portrait post (tall)" },
      { kind: "ig_landscape_1080x566", label: "Instagram 1080×566", aspect: "1080/566", hint: "Landscape post" },
      { kind: "fb_post_1080", label: "Facebook 1080×1080", aspect: "1/1", hint: "Square post" },
      { kind: "fb_cover_851x315", label: "Facebook Cover 851×315", aspect: "851/315", hint: "Page cover image" },
      { kind: "linkedin_profile_400", label: "LinkedIn Profile 400×400", aspect: "1/1", hint: "Profile picture • Round crop" },
      { kind: "linkedin_cover_1584x396", label: "LinkedIn Cover 1584×396", aspect: "4/1", hint: "Profile/company cover" },
      { kind: "youtube_cover_2560x1440", label: "YouTube Cover 2560×1440", aspect: "16/9", hint: "Channel art (mind safe area)" },
      { kind: "og_1200x630", label: "OpenGraph 1200×630", aspect: "1200/630", hint: "Link preview image" }
    ]
  end

  def update_settings
    record = @profile.profile_card || @profile.build_profile_card
    # Allow: ai | default | color
    permitted = params.permit(:bg_choice_card, :bg_color_card, :bg_choice_og, :bg_color_og, :bg_choice_simple, :bg_color_simple, :avatar_choice,
      :bg_fx_card, :bg_fy_card, :bg_zoom_card, :bg_fx_og, :bg_fy_og, :bg_zoom_og, :bg_fx_simple, :bg_fy_simple, :bg_zoom_simple, :ai_art_opt_in)
    attrs = permitted.to_h

    # Update profile-level flags
    if permitted.key?(:ai_art_opt_in)
      @profile.ai_art_opt_in = ActiveModel::Type::Boolean.new.cast(permitted[:ai_art_opt_in])
      @profile.save(validate: false)
    end

    # If user chose "Use these background settings for all card types",
    # propagate Card choices to OG and Simple before saving.
    apply_everywhere = ActiveModel::Type::Boolean.new.cast(params[:apply_everywhere])
    if apply_everywhere
      if attrs.key?("bg_choice_card")
        attrs["bg_choice_og"] = attrs["bg_choice_card"]
        attrs["bg_choice_simple"] = attrs["bg_choice_card"]
      end
      if attrs.key?("bg_color_card")
        attrs["bg_color_og"] = attrs["bg_color_card"]
        attrs["bg_color_simple"] = attrs["bg_color_card"]
      end
      # Propagate crop/zoom controls if provided for Card
      %w[bg_fx bg_fy bg_zoom].each do |base|
        card_key = "#{base}_card"
        next unless attrs.key?(card_key)
        attrs["#{base}_og"] = attrs[card_key]
        attrs["#{base}_simple"] = attrs[card_key]
      end
    end

    # Guard: avatar_choice can be 'real' or 'ai'
    if attrs.key?("avatar_choice")
      choice = attrs["avatar_choice"].to_s
      attrs["avatar_choice"] = (choice == "ai") ? "ai" : "real"
    end

    record.assign_attributes(attrs)
    if record.save
      # Structured log for observability
      StructuredLogger.info(
        message: "settings_updated",
        controller: self.class.name,
        login: @profile.login,
        apply_everywhere: apply_everywhere,
        avatar_choice: record.avatar_choice,
        bg_choice_card: record.bg_choice_card,
        bg_choice_og: record.bg_choice_og,
        bg_choice_simple: record.bg_choice_simple
      ) if defined?(StructuredLogger)
      redirect_to my_profile_settings_path(username: @profile.login), notice: "Settings updated"
    else
      redirect_to my_profile_settings_path(username: @profile.login), alert: "Could not save settings"
    end
  end

  def regenerate
    # Soft throttle to avoid abuse/cost: block if screenshots ran in the last 10 minutes
    recent = ProfilePipelineEvent.where(profile_id: @profile.id, stage: "screenshots").order(created_at: :desc).limit(1).pluck(:created_at).first rescue nil
    if recent && recent > 10.minutes.ago
      wait_m = ((recent + 10.minutes - Time.current) / 60.0).ceil
      return redirect_to my_profile_settings_path(username: @profile.login), alert: "Please wait ~#{wait_m}m before re-capturing screenshots again"
    end

    # Re-capture non-AI screenshots and optimize only
    Profiles::GeneratePipelineJob.perform_later(@profile.login, ai: false)
    @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
    redirect_to my_profile_settings_path(username: @profile.login), notice: "Re-capture queued for @#{@profile.login} — Screenshots-Only (no AI cost)"
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
    redirect_to my_profile_settings_path(username: @profile.login), notice: "Full (AI) regeneration queued for @#{@profile.login} (weekly limit)"
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
      unless content_type.start_with?("image/")
        return redirect_to my_profile_settings_path(username: @profile.login), alert: "Only image uploads are allowed"
      end
      filename = "#{@profile.login}-#{kind}-custom#{File.extname(file.original_filename.to_s)}"
      up = Storage::ActiveStorageUploadService.call(path: file.path, content_type: content_type, filename: filename)
      return redirect_to my_profile_settings_path(username: @profile.login), alert: (up.error&.message || "Upload failed") if up.failure?

      public_url = up.value[:public_url]

      # Best-effort: copy to public/generated for local fallback
      safe_login = @profile.login.to_s.downcase.gsub(/[^a-z0-9\-]/, "")
      if safe_login.present?
        begin
          dir = Rails.root.join("public", "generated", safe_login)
          FileUtils.mkdir_p(dir)
          target = dir.join("#{kind}-custom#{File.extname(filename)}")
          FileUtils.cp(file.path, target)
        rescue StandardError
          # ignore copy failures
        end
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

  # Select a specific generated asset as the active one for a given kind.
  # This sets the ProfileAsset public_url/local_path for the canonical kind by copying from another file path/URL.
  def select_asset
    kind = params[:kind].to_s
    source_url = params[:public_url].to_s
    source_path = params[:local_path].to_s
    unless %w[og card simple avatar_3x1 avatar_16x9 avatar_1x1].include?(kind)
      return redirect_to my_profile_settings_path(username: @profile.login), alert: "Unsupported kind"
    end

    begin
      # Update the canonical asset row for kind
      rec = @profile.profile_assets.find_or_initialize_by(kind: kind)
      rec.public_url = source_url.presence || rec.public_url
      rec.local_path = source_path.presence || rec.local_path
      rec.provider = rec.provider.presence || "user_select"
      rec.generated_at = Time.current
      rec.save!
      redirect_to my_profile_settings_path(username: @profile.login), notice: "Selected #{kind.humanize} image"
    rescue StandardError => e
      redirect_to my_profile_settings_path(username: @profile.login), alert: e.message
    end
  end

  def destroy
    ownership = ProfileOwnership.find_by(user_id: current_user.id, profile_id: @profile.id)
    return redirect_to my_profiles_path, alert: "Not linked to this profile" unless ownership
    if ownership.is_owner
      return redirect_to my_profiles_path, alert: "You are the owner. Transfer in Ops to remove it."
    end
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
