class Battle < ApplicationRecord
  # Associations
  belongs_to :challenger_profile, class_name: "Profile", foreign_key: :challenger_profile_id
  belongs_to :opponent_profile, class_name: "Profile", foreign_key: :opponent_profile_id
  belongs_to :winner_profile, class_name: "Profile", foreign_key: :winner_profile_id, optional: true

  # Validations
  validates :challenger_profile_id, :opponent_profile_id, presence: true
  validates :status, inclusion: { in: %w[pending in_progress completed] }
  validates :challenger_hp, :opponent_hp, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :different_profiles

  # Scopes
  scope :completed, -> { where(status: "completed") }
  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_profile, ->(profile_id) {
    where("challenger_profile_id = ? OR opponent_profile_id = ?", profile_id, profile_id)
  }

  # Instance methods
  def challenger
    challenger_profile
  end

  def opponent
    opponent_profile
  end

  def winner
    winner_profile
  end

  def loser_profile
    return nil unless winner_profile_id.present?
    winner_profile_id == challenger_profile_id ? opponent_profile : challenger_profile
  end

  def completed?
    status == "completed"
  end

  def pending?
    status == "pending"
  end

  def in_progress?
    status == "in_progress"
  end

  def add_log_entry(entry)
    self.battle_log ||= []
    self.battle_log << entry.merge(timestamp: Time.current.to_i)
  end

  def battle_summary
    return nil unless completed?

    {
      winner: winner_profile&.login,
      loser: loser_profile&.login,
      turns: battle_log.length,
      final_hp: {
        challenger: challenger_hp,
        opponent: opponent_hp
      }
    }
  end

  private

  def different_profiles
    if challenger_profile_id == opponent_profile_id
      errors.add(:base, "Cannot battle yourself")
    end
  end
end
