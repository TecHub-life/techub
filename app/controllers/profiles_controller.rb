class ProfilesController < ApplicationController
  def index
    # Redirect to home if accessed without username
    redirect_to root_path
  end

  def show
    username = params[:username].downcase

    @profile = Profile.find_by(login: username)

    if @profile.present?
      # Use cached data if it's recent (less than 1 hour old)
      if @profile.last_synced_at && @profile.last_synced_at > 1.hour.ago
        load_profile_data
      else
        # Refresh if stale
        refresh_and_load_profile(username)
      end
    else
      # New profile - fetch from GitHub
      refresh_and_load_profile(username)
    end

    respond_to do |format|
      format.html { render "profiles/show" }
      format.json { render_json_profile }
    end
  rescue => e
    Rails.logger.error("Profile load failed for #{username}: #{e.class} - #{e.message}")
    respond_to do |format|
      format.html do
        flash.now[:alert] = "Unable to load profile for @#{username}. Please check the username and try again."
        render "profiles/show"
      end
      format.json { render json: { error: "Unable to load profile" }, status: :unprocessable_entity }
    end
  end

  private

  def load_profile_data
    @profile_summary = @profile.summary
    # Load structured data directly from associations
    @top_repositories = @profile.top_repositories
    @pinned_repositories = @profile.pinned_repositories
    @active_repositories = @profile.active_repositories
    @organizations = @profile.profile_organizations
    @social_accounts = @profile.profile_social_accounts
    @languages = @profile.profile_languages.order(count: :desc)
    @recent_activity = @profile.profile_activity
    @profile_readme = @profile.profile_readme
  end

  def refresh_and_load_profile(username)
    result = Profiles::SyncFromGithub.call(login: username)

    if result.success?
      @profile = result.value
      load_profile_data
    else
      Rails.logger.error(
        "Profile sync failed for #{username}: #{result.error.class} - #{result.error.message}"
      )
      flash.now[:alert] = if result.error.is_a?(Octokit::NotFound)
        "GitHub user @#{username} not found."
      else
        "Unable to load profile for @#{username} right now. Please try again later."
      end
    end
  end

  def render_json_profile
    render json: {
      profile: {
        login: @profile.login,
        name: @profile.name,
        bio: @profile.bio,
        location: @profile.location,
        email: @profile.email,
        blog: @profile.blog,
        twitter_username: @profile.twitter_username,
        company: @profile.company,
        avatar_url: @profile.avatar_url,
        github_url: @profile.html_url,
        public_repos: @profile.public_repos,
        public_gists: @profile.public_gists,
        followers: @profile.followers,
        following: @profile.following,
        created_at: @profile.github_created_at,
        updated_at: @profile.github_updated_at,
        last_synced_at: @profile.last_synced_at
      },
      summary: @profile_summary,
      languages: @languages&.map { |lang| { name: lang.name, count: lang.count } },
      social_accounts: @social_accounts&.map { |sa| { provider: sa.provider, url: sa.url, display_name: sa.display_name } },
      organizations: @organizations&.map { |org| { login: org.login, name: org.name, description: org.description, avatar_url: org.avatar_url } },
      top_repositories: @top_repositories&.map { |repo| repository_json(repo) },
      pinned_repositories: @pinned_repositories&.map { |repo| repository_json(repo) },
      active_repositories: @active_repositories&.map { |repo| repository_json(repo) },
      recent_activity: @recent_activity&.as_json,
      readme: @profile_readme&.as_json
    }
  end

  def repository_json(repo)
    {
      name: repo.name,
      full_name: repo.full_name,
      description: repo.description,
      html_url: repo.html_url,
      language: repo.language,
      stargazers_count: repo.stargazers_count,
      forks_count: repo.forks_count,
      topics: repo.repository_topics.map(&:name),
      created_at: repo.github_created_at,
      updated_at: repo.github_updated_at
    }
  end
end
