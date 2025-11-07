class MyProfilesController < MyProfiles::BaseController
  before_action :load_profile_and_authorize, only: [ :settings, :update_settings, :regenerate, :regenerate_ai, :upload_asset, :destroy, :unlist ]

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
    puts "=== 🚨 CONTROLLER DEBUG: Settings action called ==="
    puts "Params username: #{params[:username]}"
    puts "Current user: #{current_user&.id}"
    puts "Session user ID: #{session[:current_user_id]}"
    puts "Request path: #{request.path}"
    puts "Request method: #{request.method}"

    # @profile loaded by before_action
    puts "@profile after before_action: #{@profile&.login || 'NIL'}"
    puts "@profile ID: #{@profile&.id || 'NIL'}"
    puts "@profile class: #{@profile.class.name if @profile.present?}"

    if @profile.blank?
      puts "🚨 ERROR: @profile is blank! This means the profile lookup failed."
      puts "Available profiles for user #{current_user&.id}:"
      if current_user.present?
        current_user.profiles.each do |p|
          puts "  - #{p.login} (ID: #{p.id})"
        end
      end
      return redirect_to my_profiles_path, alert: "Profile not found - DEBUG: Check Rails logs"
    end

    puts "✅ Profile loaded successfully: #{@profile.login}"

    asset_kinds = %w[og og_pro card card_pro simple]
    assets = @profile.profile_assets.where(kind: asset_kinds).index_by(&:kind)
    @asset_og = assets["og"]
    @asset_og_pro = assets["og_pro"]
    @asset_card = assets["card"]
    @asset_card_pro = assets["card_pro"]
    @asset_simple = assets["simple"]

    # For UI: compute AI regen availability
    @ai_regen_available_at = (@profile.last_ai_regenerated_at || Time.at(0)) + 7.days

    @profile_links = @profile.profile_links.order(:position, :created_at)
    @profile_achievements = @profile.profile_achievements.order(:position, :created_at)
    @profile_experiences = @profile.profile_experiences.includes(:profile_experience_skills).order(:position, :created_at)
    @profile_preferences = @profile.preferences
    @avatar_library_options = AppearanceLibrary.avatar_options
    @supporting_art_options = AppearanceLibrary.supporting_art_options
    @banner_library_options = AppearanceLibrary.banner_options

    puts "✅ Settings action completed successfully"
  end

  def update_settings
    record = @profile.profile_card || @profile.build_profile_card
    # Allow: ai | default | color
    permitted = params.permit(:bg_choice_card, :bg_color_card, :bg_choice_og, :bg_color_og, :bg_choice_simple, :bg_color_simple,
      :bg_fx_card, :bg_fy_card, :bg_zoom_card, :bg_fx_og, :bg_fy_og, :bg_zoom_og, :bg_fx_simple, :bg_fy_simple, :bg_zoom_simple, :ai_art_opt_in,
      :hireable_override, :banner_choice, :banner_library_path,
      :avatar_default_mode, :avatar_default_path,
      :avatar_profile_mode, :avatar_profile_path,
      :avatar_card_mode, :avatar_card_path,
      :avatar_og_mode, :avatar_og_path,
      :avatar_simple_mode, :avatar_simple_path,
      :avatar_square_mode, :avatar_square_path,
      :avatar_banner_mode, :avatar_banner_path,
      :bg_library_card, :bg_library_og, :bg_library_simple)
    attrs = permitted.to_h
    preferred_kind_param = params[:preferred_og_kind].to_s.presence

    # Update profile-level flags
    if permitted.key?(:ai_art_opt_in)
      @profile.ai_art_opt_in = ActiveModel::Type::Boolean.new.cast(permitted[:ai_art_opt_in])
      @profile.save(validate: false)
    end

    # Hireable override: always set from checkbox (includes hidden 0 when unchecked)
    if permitted.key?(:hireable_override)
      @profile.update_columns(hireable_override: ActiveModel::Type::Boolean.new.cast(permitted[:hireable_override]))
    end

    # Remove profile-level fields from card attributes
    attrs.delete("ai_art_opt_in")
    attrs.delete("hireable_override")

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

    avatar_payload = params[:tab].to_s == "general" ? build_avatar_sources_payload : nil
    if avatar_payload
      sources = record.avatar_sources_hash
      avatar_payload[:clear].each { |variant| sources.delete(variant) }
      sources.merge!(avatar_payload[:set])
      record.avatar_sources = sources
    end

    bg_library_payload = params[:tab].to_s == "backgrounds" ? build_bg_library_payload : nil
    if bg_library_payload
      bg_sources = record.bg_sources_hash
      bg_library_payload[:clear].each do |variant|
        bg_sources.delete(variant)
        bg_sources.delete("square") if variant == "simple"
      end
      bg_library_payload[:set].each do |variant, data|
        bg_sources[variant] = data
        bg_sources["square"] = data if variant == "simple"
      end
      record.bg_sources = bg_sources
    end

    preference_updated = apply_preferred_og_kind(preferred_kind_param)
    banner_saved = params[:tab].to_s == "general" ? apply_banner_settings : true

    record.assign_attributes(attrs) if attrs.present?
    card_changes = attrs.present? || avatar_payload.present? || bg_library_payload.present?
    card_saved = card_changes ? record.save : true

    if card_saved && preference_updated && banner_saved
      if (attrs.present? || avatar_payload.present? || bg_library_payload.present?) && defined?(StructuredLogger)
        StructuredLogger.info(
          message: "settings_updated",
          controller: self.class.name,
          login: @profile.login,
          apply_everywhere: apply_everywhere,
          bg_choice_card: record.bg_choice_card,
          bg_choice_og: record.bg_choice_og,
          bg_choice_simple: record.bg_choice_simple
        )
      end
      redirect_to_settings(notice: "Settings updated")
    else
      redirect_to_settings(alert: "Could not save settings")
    end
  end

  def regenerate
    # Soft throttle to avoid abuse/cost: block if screenshots ran in the last 10 minutes
    recent = ProfilePipelineEvent.where(profile_id: @profile.id, stage: "screenshots").order(created_at: :desc).limit(1).pluck(:created_at).first rescue nil
    if recent && recent > 10.minutes.ago
      wait_m = ((recent + 10.minutes - Time.current) / 60.0).ceil
      return redirect_to_settings(alert: "Please wait ~#{wait_m}m before re-capturing screenshots again")
    end

    Profiles::GeneratePipelineJob.perform_later(
      @profile.login,
      trigger_source: "my_profiles#regenerate",
      pipeline_overrides: {
        skip_stages: [ :generate_ai_profile, :notify_pipeline_outcome ],
        preserve_profile_avatar: true
      }
    )
    @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
    redirect_to_settings(notice: "Pipeline queued for @#{@profile.login}")
  end

  def regenerate_ai
    # Enforce weekly AI regeneration limits per profile
    next_allowed = (@profile.last_ai_regenerated_at || Time.at(0)) + 7.days
    if Time.current < next_allowed
      wait_h = ((next_allowed - Time.current) / 3600.0).ceil
      return redirect_to_settings(alert: "AI regeneration available in ~#{wait_h}h")
    end

    Profiles::GeneratePipelineJob.perform_later(
      @profile.login,
      trigger_source: "my_profiles#regenerate_ai"
    )
    @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil, last_ai_regenerated_at: Time.current)
    redirect_to_settings(notice: "Full regeneration queued for @#{@profile.login} (weekly limit in effect)")
  end

  def upload_asset
    kind = params[:kind].to_s
    file = params[:file]
    allowed = %w[
      og og_pro card card_pro simple
      avatar_3x1 avatar_1x1
      support_art_card support_art_og support_art_simple support_art_square
      banner_3x1
    ]
    unless allowed.include?(kind)
      return redirect_to_settings(alert: "Unsupported kind")
    end
    unless file.respond_to?(:path)
      return redirect_to_settings(alert: "No file uploaded")
    end

    begin
      # Upload to Active Storage / Spaces if enabled
      content_type = file.content_type.presence || "application/octet-stream"
      unless content_type.start_with?("image/")
        return redirect_to_settings(alert: "Only image uploads are allowed")
      end
      filename = "#{@profile.login}-#{kind}-custom#{File.extname(file.original_filename.to_s)}"
      up = Storage::ActiveStorageUploadService.call(path: file.path, content_type: content_type, filename: filename)
      return redirect_to_settings(alert: (up.error&.message || "Upload failed")) if up.failure?

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
        return redirect_to_settings(alert: (rec.error&.message || "Save failed"))
      end

      redirect_to_settings(notice: "Updated #{kind.humanize} image")
    rescue StandardError => e
      redirect_to_settings(alert: e.message)
    end
  end

  # Select a specific generated asset as the active one for a given kind.
  # This sets the ProfileAsset public_url/local_path for the canonical kind by copying from another file path/URL.
  def select_asset
    kind = params[:kind].to_s
    source_url = params[:public_url].to_s
    source_path = params[:local_path].to_s
    unless %w[og og_pro card card_pro simple avatar_3x1 avatar_16x9 avatar_1x1].include?(kind)
      return redirect_to_settings(alert: "Unsupported kind")
    end

    begin
      # Update the canonical asset row for kind
      rec = @profile.profile_assets.find_or_initialize_by(kind: kind)
      rec.public_url = source_url.presence || rec.public_url
      rec.local_path = source_path.presence || rec.local_path
      rec.provider = rec.provider.presence || "user_select"
      rec.generated_at = Time.current
      rec.save!
      redirect_to_settings(notice: "Selected #{kind.humanize} image")
    rescue StandardError => e
      redirect_to_settings(alert: e.message)
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

  def unlist
    ownership = ProfileOwnership.find_by(user_id: current_user.id, profile_id: @profile.id, is_owner: true)
    return redirect_to my_profiles_path, alert: "Only owners can delete profiles" unless ownership

    result = Profiles::UnlistService.call(profile: @profile, actor: current_user)
    if result.success?
      redirect_to my_profiles_path, notice: "Deleted @#{@profile.login}. You can re-add it anytime from Submit."
    else
      redirect_to_settings(alert: result.error&.message || "Could not delete @#{@profile.login}")
    end
  end

  private

  def build_avatar_sources_payload
    return nil unless params.key?(:avatar_default_mode)
    variants = %w[default profile card og simple square banner]
    set = {}
    clear = []

    variants.each do |variant|
      mode_key = :"avatar_#{variant}_mode"
      path_key = :"avatar_#{variant}_path"
      next unless variant == "default" || params.key?(mode_key)
      raw_mode = params[mode_key].to_s
      raw_path = params[path_key]

      if variant != "default" && (raw_mode.blank? || raw_mode == "inherit")
        clear << variant
        next
      end

      entry = normalize_avatar_entry(raw_mode, raw_path)
      if variant == "default"
        set["default"] = entry || { "id" => "github" }
      elsif entry
        set[variant] = entry
      else
        clear << variant
      end
    end

    { set: set, clear: clear }
  end

  def normalize_avatar_entry(mode, path_value)
    mode = mode.to_s
    return nil unless %w[github upload library].include?(mode)
    path = path_value.to_s if mode == "library"
    return nil if mode == "library" && !allowlisted_avatar_path?(path)
    id = AvatarSources.normalize_id(mode: mode, path: path)
    return nil if id.blank?
    { "id" => id }
  end

  def build_bg_library_payload
    variants = %w[card og simple]
    touched = variants.any? { |variant| params.key?(:"bg_library_#{variant}") }
    return nil unless touched

    set = {}
    clear = []

    variants.each do |variant|
      key = :"bg_library_#{variant}"
      next unless params.key?(key)
      path = params[key].to_s
      if allowlisted_supporting_art_path?(path)
        set[variant] = { "path" => path }
      else
        clear << variant
      end
    end

    { set: set, clear: clear }
  end

  def apply_banner_settings
    needs_update = params.key?(:banner_choice) || params.key?(:banner_library_path)
    return true unless needs_update

    choice = normalize_banner_choice_param(params[:banner_choice])
    attrs = { banner_choice: choice }

    if choice == "library"
      path = params[:banner_library_path].to_s
      attrs[:banner_library_path] = allowlisted_banner_path?(path) ? path : nil
    else
      attrs[:banner_library_path] = nil
    end

    @profile.update(attrs)
  end

  def normalize_banner_choice_param(value)
    val = value.to_s
    return "none" if val.blank?
    %w[none library upload].include?(val) ? val : "none"
  end

  def allowlisted_avatar_path?(path)
    return false if path.to_s.blank?
    AppearanceLibrary::AVATAR_DIRS.keys.any? { |prefix| path.start_with?("#{prefix}/") }
  end

  def allowlisted_supporting_art_path?(path)
    return false if path.to_s.blank?
    AppearanceLibrary::SUPPORTING_ART_DIRS.keys.any? { |prefix| path.start_with?("#{prefix}/") }
  end

  def allowlisted_banner_path?(path)
    return false if path.to_s.blank?
    AppearanceLibrary::BANNER_DIRS.keys.any? { |prefix| path.start_with?("#{prefix}/") }
  end

  def apply_preferred_og_kind(raw_kind)
    return true if raw_kind.blank?
    kind = raw_kind.to_s
    return false unless Profile::OG_VARIANT_KINDS.include?(kind)
    return true if @profile.preferred_og_kind == kind
    @profile.update_columns(preferred_og_kind: kind)
    true
  rescue StandardError
    false
  end

  # redirect_to_settings inherited from MyProfiles::BaseController
end
