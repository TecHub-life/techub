class ProfileOwnership < ApplicationRecord
  belongs_to :user
  belongs_to :profile

  validates :user_id, presence: true
  validates :profile_id, presence: true
  validate :only_one_owner
  validate :prevent_orphaned_profile

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

  def only_one_owner
    return unless is_owner && profile_id.present?
    existing = ProfileOwnership.where(profile_id: profile_id, is_owner: true)
    existing = existing.where.not(id: id) if id.present?
    errors.add(:base, "Profile already has an owner") if existing.exists?
  end

  def prevent_orphaned_profile
    return unless profile_id.present?

    # If this record is the current owner and is being changed to non-owner or destroyed,
    # ensure another owner will exist in the same transaction.
    if will_save_change_to_is_owner?
      becoming_non_owner = is_owner_change == [ true, false ]
      if becoming_non_owner
        # There must be another ownership set to owner in the same profile in this transaction.
        # Since cross-record validation is tricky, block demotion here and require transfer flow.
        errors.add(:base, "Cannot clear owner; use transfer instead")
      end
    end

    if destroyed_by_association.nil? && destroyed? && is_owner
      errors.add(:base, "Cannot delete owner link; use transfer instead")
    end
  end
end
