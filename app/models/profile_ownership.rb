class ProfileOwnership < ApplicationRecord
  belongs_to :user
  belongs_to :profile

  validates :user_id, presence: true
  validates :profile_id, presence: true

  validate :enforce_user_profile_cap

  private

  def enforce_user_profile_cap
    return unless user
    cap = (ENV["PROFILE_OWNERSHIP_CAP"].presence || 5).to_i
    current_count = user.profile_ownerships.where.not(id: id).count
    if current_count >= cap
      errors.add(:base, "You have reached the maximum number of profiles (#{cap})")
    end
  end
end
