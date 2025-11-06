class ProfileExperienceSkill < ApplicationRecord
  belongs_to :profile_experience

  validates :name, presence: true, length: { maximum: 80 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :name) }
end
