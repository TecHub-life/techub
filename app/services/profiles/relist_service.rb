module Profiles
  class RelistService < ApplicationService
    def initialize(profile:, actor: nil)
      @profile = profile
      @actor = actor
    end

    def call
      return failure(StandardError.new("Profile not found")) unless profile
      return failure(StandardError.new("Actor required")) unless actor

      ActiveRecord::Base.transaction do
        profile.update!(listed: true, unlisted_at: nil)
        ProfileOwnership.where(profile_id: profile.id).delete_all

        claim = Profiles::ClaimOwnershipService.call(user: actor, profile: profile)
        raise claim.error if claim.failure?
      end

      success(profile, metadata: metadata)
    rescue StandardError => e
      failure(e, metadata: metadata)
    end

    private

    attr_reader :profile, :actor

    def metadata
      {
        profile_id: profile&.id,
        login: profile&.login,
        actor_id: actor&.id,
        actor_login: actor&.login
      }
    end
  end
end
