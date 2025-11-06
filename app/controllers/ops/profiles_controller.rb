module Ops
  class ProfilesController < BaseController
    def generate_social_assets
      login = params[:username].to_s.downcase
      Screenshots::CaptureCardService::SOCIAL_VARIANTS.each do |kind|
        Screenshots::CaptureCardJob.perform_later(login: login, variant: kind)
      end
      redirect_to ops_admin_path, notice: "Enqueued social screenshots for @#{login}"
    end
  end
end

module Ops
  class ProfilesController < BaseController
    before_action :find_profile, only: [ :show, :retry, :destroy, :refresh_assets, :reroll_github, :refresh_avatar ]

    def show
      @top_repositories = @profile.top_repositories
      @pinned_repositories = @profile.pinned_repositories
      @active_repositories = @profile.active_repositories
      @organizations = @profile.profile_organizations
      @social_accounts = @profile.profile_social_accounts
      @languages = @profile.profile_languages.order(count: :desc)
      @recent_activity = @profile.profile_activity
      @profile_readme = @profile.profile_readme
      @profile_card = @profile.profile_card
      @profile_assets = @profile.profile_assets.order(:kind)

      @recent_events = ProfilePipelineEvent.where(profile_id: @profile.id).order(created_at: :desc).limit(50)
    end

    # Lightweight search endpoint for admin autocomplete
    # GET /ops/profiles/search?q=lo
    def search
      q = params[:q].to_s.strip.downcase
      return render json: [] if q.blank?

      results = Profile.where("LOWER(login) LIKE ?", "%#{q}%").order(:login).limit(20)
      render json: results.map { |p| { login: p.login } }
    end

    def retry
      Profiles::GeneratePipelineJob.perform_later(@profile.login, trigger_source: "ops_profiles#retry")
      @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
      redirect_to ops_admin_path, notice: "Re-roll queued for @#{@profile.login} (full pipeline as fresh submission)"
    end

    def reroll_github
      overrides = Profiles::Pipeline::Recipes.github_sync
      enqueue_pipeline(@profile, overrides, trigger: "ops_profiles#reroll_github", notice: "GitHub data refresh queued for @#{@profile.login}")
    end

    def refresh_avatar
      overrides = Profiles::Pipeline::Recipes.avatar_refresh
      enqueue_pipeline(@profile, overrides, trigger: "ops_profiles#refresh_avatar", notice: "GitHub avatar refresh queued for @#{@profile.login}")
    end

    def reroll_ai
      Profiles::RerollAiJob.perform_later(login: params[:username].to_s.downcase)
      redirect_to ops_admin_path, notice: "AI traits regeneration queued for @#{params[:username]}"
    end

    def recapture_screenshots
      variants = (params[:variants].presence || Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS).map(&:to_s)
      Profiles::RecaptureScreenshotsJob.perform_later(login: params[:username].to_s.downcase, variants: variants)
      redirect_to ops_admin_path, notice: "Screenshot recapture queued for @#{params[:username]} (#{variants.join(', ')})"
    end

    def refresh_assets
      variants = normalized_variants(params[:variants])
      missing_only = boolean_param(params[:only_missing], default: true)
      variants = Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS if variants.empty?
      variants = @profile.missing_asset_variants(variants) if missing_only

      if variants.empty?
        redirect_to ops_admin_path, notice: "All requested assets already exist for @#{@profile.login}"
        return
      end

      overrides = Profiles::Pipeline::Recipes.screenshot_refresh(variants: variants)
      if overrides.blank?
        redirect_to ops_admin_path, alert: "No variants selected for asset refresh"
        return
      end

      enqueue_pipeline(@profile, overrides, trigger: "ops_profiles#refresh_assets", notice: "Asset refresh queued for @#{@profile.login} (#{variants.join(', ')})")
    end

    # Image regeneration removed from Ops to avoid confusion. Use Settings UI for artwork decisions.

    def destroy
      login = @profile.login
      @profile.destroy!
      dest = ops_admin_path
      dest = "#{dest}#{params[:back_to]}" if params[:back_to].present?
      redirect_to dest, notice: "Deleted profile @#{login}"
    rescue ActiveRecord::InvalidForeignKey => e
      dest = ops_admin_path
      dest = "#{dest}#{params[:back_to]}" if params[:back_to].present?
      redirect_to dest, alert: "Could not delete: #{e.message}"
    end

    private

    def find_profile
      @profile = Profile.for_login(params[:username]).first
      redirect_to ops_admin_path, alert: "Profile not found" unless @profile
    end

    def normalized_variants(values)
      list = case values
      when String
        values.split(/[,\s]+/)
      else
        Array(values)
      end
      list.map { |v| v.to_s.strip.downcase }.reject(&:blank?).uniq
    end

    def boolean_param(value, default: false)
      return default if value.nil?

      ActiveModel::Type::Boolean.new.cast(value)
    end

    def enqueue_pipeline(profile, overrides, trigger:, notice:)
      opts = { trigger_source: trigger }
      opts[:pipeline_overrides] = overrides if overrides.present?
      Profiles::GeneratePipelineJob.perform_later(profile.login, opts)
      profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
      redirect_to ops_admin_path, notice: notice
    end
  end
end
