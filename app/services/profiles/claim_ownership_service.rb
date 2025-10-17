module Profiles
  class ClaimOwnershipService < ApplicationService
    def initialize(user:, login: nil, profile: nil)
      @user = user
      @login = login&.to_s&.downcase
      @profile = profile || Profile.for_login(@login).first
    end

    def call
      return failure(StandardError.new("User is required")) unless user
      return failure(StandardError.new("Profile not found")) unless profile

      ActiveRecord::Base.transaction do
        ownership = ProfileOwnership.find_or_initialize_by(user_id: user.id, profile_id: profile.id)

        # If this user is the rightful owner (login match), set as owner and remove other links
        if user.login.to_s.downcase == profile.login.to_s.downcase
          ownership.is_owner = true
          unless ownership.save
            return failure(StandardError.new(ownership.errors.full_messages.to_sentence))
          end
          # Collect impacted users before deleting
          impacted_ids = ProfileOwnership.where(profile_id: profile.id).where.not(user_id: user.id).pluck(:user_id)
          ProfileOwnership.where(profile_id: profile.id).where.not(user_id: user.id).delete_all

          # Notifications (best-effort, outside transaction commit issues tolerated here)
          Notifications::RecordEventService.call(user: user, event: :ownership_claimed, subject: profile)
          impacted_ids.uniq.each do |uid|
            if (u = User.find_by(id: uid))
              Notifications::RecordEventService.call(user: u, event: :ownership_link_removed, subject: profile)
            end
          end
        else
          ownership.is_owner = ownership.is_owner || false
          unless ownership.save
            return failure(StandardError.new(ownership.errors.full_messages.to_sentence))
          end
        end
      end

      success(profile)
    rescue StandardError => e
      failure(e)
    end

    private
    attr_reader :user, :login, :profile
  end
end
