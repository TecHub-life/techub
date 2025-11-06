class ProfileExperience < ApplicationRecord
  include ProfileShowcaseItem

  EMPLOYMENT_TYPES = %w[full_time part_time self_employed freelance contract internship apprenticeship].freeze
  LOCATION_TYPES = %w[on_site hybrid remote].freeze

  has_many :profile_experience_skills, -> { order(:position, :name) }, dependent: :destroy, inverse_of: :profile_experience

  validates :title, presence: true, length: { maximum: 160 }
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }, allow_blank: true
  validates :organization, length: { maximum: 160 }, allow_blank: true
  validates :organization_url, length: { maximum: 2048 }, allow_blank: true
  validates :location, length: { maximum: 160 }, allow_blank: true
  validates :location_type, inclusion: { in: LOCATION_TYPES }, allow_blank: true
  validates :description, length: { maximum: 2000 }, allow_blank: true

  before_validation :sync_dates_for_current_role

  scope :chronological, -> { order(Arel.sql("COALESCE(started_on, '1900-01-01') ASC")) }
  scope :reverse_chronological, -> { order(Arel.sql("COALESCE(started_on, '1900-01-01') DESC")) }

  def manual_position
    position || 0
  end

  def date_range
    start_text = started_on&.strftime("%b %Y")
    end_text = current_role? ? "Present" : ended_on&.strftime("%b %Y")
    [ start_text, end_text ].compact.join(" - ")
  end

  private

  def sync_dates_for_current_role
    return unless current_role?

    self.ended_on = nil
  end
end
