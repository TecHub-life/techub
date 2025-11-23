class ProfilesController < ApplicationController
  def index
    # Redirect to home if accessed without username
    redirect_to root_path
  end

  def show
    username = params[:username].downcase

    @profile = Profile.listed.find_by(login: username)

    if @profile.present?
      # Always serve cached data; enqueue background refresh if stale
      load_profile_data
      if @profile.needs_sync?
        Profiles::RefreshJob.perform_later(username)
      end
    else
      # Do not auto-create. Redirect to submit flow.
      redirect_to submit_path, alert: "Profile not found. Submit to add it." and return
    end

    respond_to do |format|
      format.html { render "profiles/show" }
      format.json { render_json_profile }
    end
  rescue => e
    StructuredLogger.error(message: "Profile load failed", username: username, error_class: e.class.name, error: e.message)
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
    @profile_preferences = @profile.preferences
    @profile_links = @profile.ordered_links(include_hidden: true)
    @profile_achievements = @profile.ordered_achievements(include_hidden: true)
    @profile_experiences = @profile.ordered_experiences(include_hidden: true)
    @pinned_showcase_items = @profile.pinned_showcase_items
    @hidden_showcase_count = @profile.hidden_showcase_count

    # Load historical stats for charts (last 30 days)
    @stats_history = @profile.profile_stats.order(stat_date: :asc).last(30)
  end

  def refresh_and_load_profile(username)
    # No longer used: refresh is enqueued; retained for compatibility
    Profiles::RefreshJob.perform_later(username)
    @profile = Profile.find_by(login: username)
    load_profile_data if @profile
  end

  def render_json_profile
    card = @profile&.profile_card
    render json: {
      profile: {
        login: @profile.login,
        name: @profile.name,
        bio: @profile.bio,
        location: @profile.location,
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
        last_synced_at: @profile.last_synced_at,
        last_pipeline_status: @profile.last_pipeline_status,
        last_pipeline_error: @profile.last_pipeline_error
      },
      summary: @profile_summary.to_s,
      languages: Array(@languages).map { |lang| { name: lang.name, count: lang.count } },
      social_accounts: Array(@social_accounts).map { |sa| { provider: sa.provider, url: sa.url, display_name: sa.display_name } },
      organizations: Array(@organizations).map { |org| { login: org.login, name: org.name, description: org.description, avatar_url: org.avatar_url } },
      top_repositories: Array(@top_repositories).map { |repo| repository_json(repo) },
      pinned_repositories: Array(@pinned_repositories).map { |repo| repository_json(repo) },
      active_repositories: Array(@active_repositories).map { |repo| repository_json(repo) },
      recent_activity: @recent_activity&.as_json || {},
      readme: @profile_readme&.as_json || {},
      card: card && {
        title: card.title,
        tagline: card.tagline,
        short_bio: card.short_bio,
        long_bio: card.long_bio,
        buff: card.buff,
        buff_description: card.buff_description,
        weakness: card.weakness,
        weakness_description: card.weakness_description,
        flavor_text: card.flavor_text,
        attack: card.attack,
        defense: card.defense,
        speed: card.speed,
        playing_card: card.playing_card,
        spirit_animal: card.spirit_animal,
        archetype: card.archetype,
        vibe: card.vibe,
        vibe_description: card.vibe_description,
        special_move: card.special_move,
        special_move_description: card.special_move_description,
        tags: Array(card.tags),
        model_name: card.model_name,
        generated_at: card.generated_at
      }
    }
  end

  public

  def status
    username = params[:username].to_s.downcase
    profile = Profile.listed.for_login(username).first
    if profile.nil?
      return render json: { status: "missing" }, status: :ok
    end
    state = profile.last_pipeline_status.presence || "unknown"
    render json: { status: state }, status: :ok
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
