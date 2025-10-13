class SubmissionsController < ApplicationController
  before_action :require_login

  def create
    login = submission_params[:login].to_s.downcase.strip
    if login.blank?
      return redirect_to submit_path, alert: "GitHub username is required"
    end

    # Ownership cap (default 5)
    actor = current_user || User.find_by(id: session[:current_user_id])
    if actor.nil?
      return redirect_to auth_github_path, alert: "Please sign in with GitHub"
    end

    if actor.profiles.count >= (ENV["PROFILE_OWNERSHIP_CAP"].presence || 5).to_i
      return redirect_to submit_path, alert: "You have reached the maximum number of profiles"
    end

    # Optimistically link ownership immediately if profile already exists
    if (existing = Profile.for_login(login).first)
      begin
        ProfileOwnership.find_or_create_by!(user: actor, profile: existing)
      rescue ActiveRecord::RecordInvalid
        # ignore; background job will handle linkage
      end
    end

    # Enqueue async submission job (sync + ownership + manual inputs + pipeline)
    Profiles::SubmitProfileJob.perform_later(
      login,
      actor.id,
      submitted_scrape_url: submission_params[:submitted_scrape_url],
      submitted_repositories: submission_params[:submitted_repositories]
    )

    redirect_to my_profiles_path, notice: "Submission queued for @#{login}. It will appear here when ready."
  rescue StandardError => e
    StructuredLogger.error(message: "submission_failed", error_class: e.class.name, error: e.message)
    redirect_to submit_path, alert: "Submission failed: #{e.message}"
  end

  private

  def require_login
    @current_user ||= User.find_by(id: session[:current_user_id]) if @current_user.nil? && session[:current_user_id].present?
    return if current_user.present?
    redirect_to auth_github_path, alert: "Please sign in with GitHub"
  end

  def submission_params
    params.permit(:login, :submitted_scrape_url, submitted_repositories: [])
  end

  def evaluate_eligibility(profile)
    repositories = profile.profile_repositories.map do |r|
      { private: false, archived: false, pushed_at: r.github_updated_at, owner_login: (r.full_name&.split("/")&.first || profile.login) }
    end
    recent_activity = { total_events: profile.profile_activity&.total_events.to_i }
    pinned = profile.profile_repositories.where(repository_type: "pinned").map { |r| { name: r.name } }
    readme = profile.profile_readme&.content
    orgs = profile.profile_organizations.map { |o| { login: o.login } }
    payload = { login: profile.login, followers: profile.followers, following: profile.following, created_at: profile.github_created_at }

    Eligibility::GithubProfileScoreService.call(
      profile: payload,
      repositories: repositories,
      recent_activity: recent_activity,
      pinned_repositories: pinned,
      profile_readme: readme,
      organizations: orgs
    ).value
  end
end
