class ProfileActivity < ApplicationRecord
  belongs_to :profile

  validates :total_events, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { where("last_active > ?", 1.week.ago) }
  scope :active, -> { where("total_events > 0") }

  def event_types
    event_breakdown.keys
  end

  def most_common_event_type
    event_breakdown.max_by { |_type, count| count }&.first
  end

  def activity_score
    # Simple activity scoring based on events and recency
    base_score = total_events
    recency_bonus = last_active.present? && last_active > 1.week.ago ? 10 : 0
    base_score + recency_bonus
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
end
