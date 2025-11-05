class ProfileActivity < ApplicationRecord
  belongs_to :profile

  validates :total_events, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_validation :ensure_activity_metrics

  scope :recent, -> { where("last_active > ?", 1.week.ago) }
  scope :active, -> { where("total_events > 0") }

  def event_types
    event_breakdown.keys
  end

  def most_common_event_type
    event_breakdown.max_by { |_type, count| count }&.first
  end

  def activity_score
    # Blend GitHub events with contribution streaks for richer scoring
    base_score = total_events
    metrics = activity_metrics

    contribution_bonus = metrics.fetch("total_contributions", 0).to_i / 10
    streak_bonus = metrics.fetch("current_streak", 0).to_i * 2
    recency_bonus = last_active.present? && last_active > 1.week.ago ? 10 : 0

    base_score + contribution_bonus + streak_bonus + recency_bonus
  end

  def is_active?
    last_active.present? && last_active > 1.month.ago
  end

  def recent_repositories_list
    return [] if recent_repos.blank?

    begin
      JSON.parse(recent_repos)
    rescue JSON::ParserError
      []
    end
  end

  def activity_metrics
    self[:activity_metrics].presence || {}
  end

  def activity_metric_value(key)
    activity_metrics.fetch(key.to_s, 0).to_i
  end

  private

  def ensure_activity_metrics
    self.activity_metrics = {} if self[:activity_metrics].nil?
  end
end
