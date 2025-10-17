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

        has_owner = ProfileOwnership.where(profile_id: profile.id, is_owner: true).exists?

        if has_owner
          # If this user is the rightful owner (login match), transfer ownership to them
          if user.login.to_s.downcase == profile.login.to_s.downcase
            impacted_ids = ProfileOwnership.where(profile_id: profile.id).where.not(user_id: user.id).pluck(:user_id)
            # Remove all other links (including prior owner) first to satisfy single-owner validation
            ProfileOwnership.where(profile_id: profile.id).where.not(user_id: user.id).delete_all

            ownership.is_owner = true
            unless ownership.save
              return failure(StandardError.new(ownership.errors.full_messages.to_sentence))
            end

            Notifications::RecordEventService.call(user: user, event: :ownership_claimed, subject: profile)
            impacted_ids.uniq.each do |uid|
              if (u = User.find_by(id: uid))
                Notifications::RecordEventService.call(user: u, event: :ownership_link_removed, subject: profile)
              end
            end
          else
            # Profile already has an owner and submitter is not the rightful owner; do nothing
          end
        else
          # No owner yet: first submitter becomes owner (regardless of login match)
          ownership.is_owner = true
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
