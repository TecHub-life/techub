module Ops
  class ProfilesController < BaseController
    before_action :find_profile

    def show
      @top_repositories = @profile.top_repositories
      @pinned_repositories = @profile.pinned_repositories
      @active_repositories = @profile.active_repositories
      @organizations = @profile.profile_organizations
      @social_accounts = @profile.profile_social_accounts
      @languages = @profile.profile_languages.order(count: :desc)
      @recent_activity = @profile.profile_activity
      @profile_readme = @profile.profile_readme

      @recent_events = ProfilePipelineEvent.where(profile_id: @profile.id).order(created_at: :desc).limit(50)
    end

    def retry
      Profiles::GeneratePipelineJob.perform_later(@profile.login, ai: false)
      @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil)
      redirect_to ops_admin_path, notice: "Re-run queued for @#{@profile.login} (no AI)"
    end

    def retry_ai
      Profiles::GeneratePipelineJob.perform_later(@profile.login, ai: true)
      @profile.update_columns(last_pipeline_status: "queued", last_pipeline_error: nil, last_ai_regenerated_at: Time.current)
      redirect_to ops_admin_path, notice: "AI re-run queued for @#{@profile.login}"
    end

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
