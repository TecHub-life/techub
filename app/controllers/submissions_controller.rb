class SubmissionsController < ApplicationController
  before_action :require_login

  def create
    login = submission_params[:login].to_s.downcase.strip
    Observability::Tracing.with_span(
      "submissions.create",
      attributes: {
        "http.route" => "/submit",
        "http.method" => request.request_method,
        "submission.login.present" => login.present?
      },
      tracer_key: :controller,
      kind: :server
    ) do |span|
      if login.blank?
        span&.set_attribute("submission.status", "missing_login")
        return redirect_to submit_path, alert: "GitHub username is required"
      end

      # Ownership cap (default 5)
      actor = current_user || User.find_by(id: session[:current_user_id])
      span&.set_attribute("submission.actor_id", actor&.id)
      if actor.nil?
        span&.set_attribute("submission.status", "auth_required")
        return redirect_to auth_github_path, alert: "Please sign in with GitHub"
      end

      if actor.profiles.count >= (ENV["PROFILE_OWNERSHIP_CAP"].presence || 5).to_i
        span&.set_attribute("submission.status", "ownership_cap")
        return redirect_to submit_path, alert: "You have reached the maximum number of profiles"
      end

      existing = Profile.for_login(login).first
      span&.set_attribute("submission.profile_exists", existing.present?)
      if existing&.unlisted?
        relist = Profiles::RelistService.call(profile: existing, actor: actor)
        span&.set_attribute("submission.relist_success", relist.success?)
        if relist.success?
          return redirect_to my_profiles_path, notice: "@#{login} was restored and is available in your profiles."
        end
        return redirect_to submit_path, alert: relist.error&.message || "Could not restore @#{login}"
      end

      # Existing profile handling:
      if existing
        has_owner = ProfileOwnership.where(profile_id: existing.id, is_owner: true).exists?
        span&.set_attribute("submission.profile_has_owner", has_owner)
        if !has_owner
          Profiles::ClaimOwnershipService.call(user: actor, profile: existing)
        elsif actor.login.to_s.downcase == existing.login.to_s.downcase
          Profiles::ClaimOwnershipService.call(user: actor, profile: existing)
        else
          span&.set_attribute("submission.status", "duplicate_profile")
          return redirect_to submit_path, alert: "@#{login} already exists."
        end
      end

      # Enqueue async submission job (sync + ownership + manual inputs + pipeline)
      payload = {
        submitted_scrape_url: submission_params[:submitted_scrape_url],
        submitted_repositories: submission_params[:submitted_repositories]
      }
      if Rails.env.test?
        Profiles::SubmitProfileJob.perform_now(login, actor.id, **payload)
        span&.set_attribute("submission.enqueue_mode", "inline")
      else
        Profiles::SubmitProfileJob.perform_later(login, actor.id, **payload)
        span&.set_attribute("submission.enqueue_mode", "async")
      end

      span&.set_attribute("submission.status", "enqueued")
      redirect_to my_profiles_path, notice: "Submission queued for @#{login}. It will appear here when ready."
    end
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
