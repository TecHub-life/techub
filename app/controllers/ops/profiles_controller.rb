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
    before_action :find_profile, only: [ :show, :retry, :destroy ]

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
      Profiles::GeneratePipelineJob.perform_later(@profile.login)
      @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
      redirect_to ops_admin_path, notice: "Pipeline run queued for @#{@profile.login}"
    end

    # Image regeneration removed from Ops to avoid confusion. Use Settings UI for artwork decisions.

    def destroy
      login = @profile.login
      @profile.destroy!
      redirect_to ops_admin_path, notice: "Deleted profile @#{login}"
    rescue ActiveRecord::InvalidForeignKey => e
      redirect_to ops_admin_path, alert: "Could not delete: #{e.message}"
    end

    private

    def find_profile
      @profile = Profile.for_login(params[:username]).first
      redirect_to ops_admin_path, alert: "Profile not found" unless @profile
    end
  end
end
