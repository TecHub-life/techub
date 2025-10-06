class Profile < ApplicationRecord
  # Associations
  has_many :profile_repositories, dependent: :destroy
  has_many :profile_organizations, dependent: :destroy
  has_many :profile_social_accounts, dependent: :destroy
  has_many :profile_languages, dependent: :destroy
  has_one :profile_activity, dependent: :destroy
  has_one :profile_readme, dependent: :destroy

  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :login, presence: true, uniqueness: true

  # Scopes
  scope :for_login, ->(login) { where(login: login.downcase) }
  scope :hireable, -> { where(hireable: true) }
  scope :recently_active, -> { joins(:profile_activity).where("profile_activities.last_active > ?", 1.week.ago) }

  # Repository methods
  def top_repositories
    profile_repositories.where(repository_type: "top").order(stargazers_count: :desc)
  end

  def pinned_repositories
    profile_repositories.where(repository_type: "pinned")
  end

  def active_repositories
    profile_repositories.where(repository_type: "active")
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

  def display_name
    name.presence || login
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
end
