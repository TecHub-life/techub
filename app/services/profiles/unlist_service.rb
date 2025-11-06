module Profiles
  class UnlistService < ApplicationService
    def initialize(profile:, actor: nil)
      @profile = profile
      @actor = actor
    end

    def call
      return failure(StandardError.new("Profile not found")) unless profile
      return success(profile) if profile.unlisted?

      ActiveRecord::Base.transaction do
        profile.update!(listed: false, unlisted_at: Time.current)
        ProfileOwnership.where(profile_id: profile.id).delete_all
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
