class ProfileAchievement < ApplicationRecord
  include ProfileShowcaseItem

  validates :title, presence: true, length: { maximum: 160 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :timezone, length: { maximum: 100 }, allow_blank: true
  validates :date_display_mode, inclusion: { in: %w[profile_default yyyy_mm_dd dd_mm_yyyy relative] }

  before_validation :sync_occurred_on

  scope :chronological, -> { order(occurred_at: :asc, occurred_on: :asc, created_at: :asc) }
  scope :reverse_chronological, -> { order(occurred_at: :desc, occurred_on: :desc, created_at: :desc) }

  def manual_position
    position || 0
  end

  private

  def sync_occurred_on
    return if occurred_on.present? || occurred_at.blank?

    self.occurred_on = occurred_at.to_date
  end
end
