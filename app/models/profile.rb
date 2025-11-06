class Profile < ApplicationRecord
  # Associations
  has_many :profile_repositories, dependent: :destroy
  has_many :profile_organizations, dependent: :destroy
  has_many :profile_social_accounts, dependent: :destroy
  has_many :profile_languages, dependent: :destroy
  has_one :profile_activity, dependent: :destroy
  has_one :profile_readme, dependent: :destroy
  has_one :profile_card, dependent: :destroy
  has_one :profile_preference, dependent: :destroy
  has_many :profile_assets, dependent: :destroy
  has_many :profile_scrapes, dependent: :destroy
  has_many :profile_stats, dependent: :destroy
  has_many :profile_pipeline_events, dependent: :destroy
  has_many :profile_ownerships, dependent: :destroy
  has_many :owners, through: :profile_ownerships, source: :user
  has_many :profile_links, -> { order(:position, :created_at) }, dependent: :destroy
  has_many :profile_achievements, -> { order(:position, :created_at) }, dependent: :destroy
  has_many :profile_experiences, -> { order(:position, :created_at) }, dependent: :destroy

  OG_VARIANT_KINDS = %w[og og_pro].freeze

  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :login, presence: true, uniqueness: { case_sensitive: false }

  before_validation do
    self.login = login.to_s.downcase
  end

  after_create :ensure_profile_preference_record

  # Scopes
  scope :for_login, ->(login) { where(login: login.downcase) }
  scope :listed, -> { where(listed: true) }
  scope :unlisted, -> { where(listed: false) }
  scope :hireable, -> { where(hireable: true) }
  scope :recently_active, -> { joins(:profile_activity).where("profile_activities.last_active > ?", 1.week.ago) }

  # Repository methods
  def top_repositories
    profile_repositories
      .where(repository_type: "top")
      .includes(:repository_topics)
      .order(stargazers_count: :desc)
  end

  def pinned_repositories
    profile_repositories
      .where(repository_type: "pinned")
      .includes(:repository_topics)
  end

  def active_repositories
    profile_repositories
      .where(repository_type: "active")
      .includes(:repository_topics)
  end

  def active_repositories_filtered
    # Filter active repositories to only show user's own repos or org repos
    user_orgs = organization_logins
    profile_repositories.where(repository_type: "active").select do |repo|
      # repo.full_name is in format "owner/repo"
      owner = repo.full_name.split("/").first
      owner == login || user_orgs.include?(owner)
    end
  end

  # Language methods
  def language_breakdown
    profile_languages.order(count: :desc).pluck(:name, :count).to_h
  end

  def top_languages(limit = 5)
    profile_languages.order(count: :desc).limit(limit)
  end

  # Activity methods
  def recent_activity_data
    profile_activity || ProfileActivity.new
  end

  def last_active
    recent_activity_data.last_active
  end

  def total_events
    recent_activity_data.total_events
  end

  def event_breakdown
    recent_activity_data.event_breakdown || {}
  end

  # README methods
  def readme_content
    profile_readme&.content
  end

  def has_readme?
    readme_content.present?
  end

  # Organization methods
  def organization_names
    profile_organizations.pluck(:name).compact
  end

  def organization_logins
    profile_organizations.pluck(:login)
  end

  # Preferences / showcase helpers
  def preferences
    profile_preference || build_profile_preference
  end

  def preference_default(field, fallback)
    record = preferences
    return fallback unless record.respond_to?(field)

    value = record.public_send(field)
    value.nil? ? fallback : value
  rescue StandardError
    fallback
  end

  def showcase_pin_limit
    preference_default(:pin_limit, 5)
  end

  def ordered_links(include_hidden: false)
    scope = include_hidden ? profile_links.active : profile_links.visible
    sort_mode = preferences.sort_mode_for(:links)
    sort_links(scope, sort_mode)
  end

  def ordered_achievements(include_hidden: false)
    scope = include_hidden ? profile_achievements.active : profile_achievements.visible
    sort_mode = preferences.sort_mode_for(:achievements)
    sort_achievements(scope, sort_mode)
  end

  def ordered_experiences(include_hidden: false)
    scope = include_hidden ? profile_experiences.active : profile_experiences.visible
    sort_mode = preferences.sort_mode_for(:experiences)
    sort_experiences(scope, sort_mode)
  end

  def pinned_showcase_items
    links = profile_links.pinned
    achievements = profile_achievements.pinned
    experiences = profile_experiences.pinned
    (links + achievements + experiences).sort_by do |item|
      [ item.pin_position || 0, item.created_at.to_i ]
    end.take(showcase_pin_limit)
  end

  def hidden_showcase_count
    profile_links.hidden_only.count + profile_achievements.hidden_only.count + profile_experiences.hidden_only.count
  end

  # Social account methods
  def social_accounts_by_provider
    profile_social_accounts.group_by(&:provider)
  end

  def twitter_account
    profile_social_accounts.find_by(provider: "TWITTER")
  end

  def bluesky_account
    profile_social_accounts.find_by(provider: "BLUESKY")
  end

  # Utility methods
  def github_profile_url
    html_url || "https://github.com/#{login}"
  end

  def preferred_og_kind
    kind = self[:preferred_og_kind].presence || "og"
    OG_VARIANT_KINDS.include?(kind) ? kind : "og"
  end

  def display_name
    name.presence || login
  end

  # Returns whether to display the hireable badge, considering user override.
  # If hireable_override is nil, fall back to GitHub-derived hireable field.
  def hireable_display?
    return hireable unless has_attribute?(:hireable_override)
    override = self[:hireable_override]
    override.nil? ? hireable : !!override
  end

  def needs_sync?
    last_synced_at.nil? || last_synced_at < 1.hour.ago
  end

  def data_completeness
    required_fields = %w[github_id login name]
    optional_fields = %w[bio company location blog email twitter_username]

    required_present = required_fields.count { |field| send(field).present? }
    optional_present = optional_fields.count { |field| send(field).present? }

    {
      required_completeness: (required_present * 100.0 / required_fields.count).round(1),
      optional_completeness: (optional_present * 100.0 / optional_fields.count).round(1),
      has_repositories: profile_repositories.exists?,
      has_organizations: profile_organizations.exists?,
      has_social_accounts: profile_social_accounts.exists?,
      has_readme: has_readme?
    }
  end

  def missing_asset_variants(desired_kinds = nil)
    kinds = Array(desired_kinds.presence || Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS)
      .map { |k| k.to_s.strip }
      .reject(&:blank?)
    return [] if kinds.empty?

    existing = profile_assets.where(kind: kinds).pluck(:kind)
    kinds - existing
  end
  def unlisted?
    !listed
  end

  def mark_unlisted!(timestamp: Time.current)
    update!(listed: false, unlisted_at: timestamp)
  end

  def mark_listed!
    update!(listed: true, unlisted_at: nil)
  end

  private

  def ensure_profile_preference_record
    profile_preference || create_profile_preference!
  rescue ActiveRecord::RecordNotUnique
    reload
    profile_preference
  end

  def sort_links(scope, mode)
    case mode
    when "alphabetical"
      scope.reorder(Arel.sql("LOWER(label) ASC"))
    when "newest"
      scope.reorder(created_at: :desc)
    when "oldest"
      scope.reorder(created_at: :asc)
    else
      scope.reorder(:position, :created_at)
    end
  end

  def sort_achievements(scope, mode)
    coalesce = Arel.sql("COALESCE(occurred_at, occurred_on)")
    case mode
    when "newest"
      scope.reorder(coalesce.desc, :created_at)
    when "oldest"
      scope.reorder(coalesce.asc, :created_at)
    else
      scope.reorder(:position, coalesce.asc, :created_at)
    end
  end

  def sort_experiences(scope, mode)
    coalesce = Arel.sql("COALESCE(started_on, '1900-01-01')")
    case mode
    when "newest"
      scope.reorder(coalesce.desc, :created_at)
    when "oldest"
      scope.reorder(coalesce.asc, :created_at)
    else
      scope.reorder(:position, coalesce.asc, :created_at)
    end
  end
end
