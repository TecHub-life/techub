require "test_helper"

module Profiles
  module Pipeline
    module Stages
      class PersistGithubProfileTest < ActiveSupport::TestCase
        def setup
          @profile = Profile.create!(
            github_id: 42,
            login: "avatar-user",
            name: "Avatar User",
            avatar_url: "https://techub.test/custom-avatar.png"
          )
        end

        test "preserves existing avatar when override enabled" do
          context = build_context(overrides: { preserve_profile_avatar: true })
          context.github_payload = github_payload
          context.avatar_public_url = "https://spaces.techub/new-avatar.png"

          result = PersistGithubProfile.call(context: context)

          assert result.success?, -> { result.error&.message }
          assert_equal "https://techub.test/custom-avatar.png", @profile.reload.avatar_url
          assert_equal "https://techub.test/custom-avatar.png", context.profile.avatar_url
        end

        test "updates avatar when override disabled" do
          context = build_context
          context.github_payload = github_payload
          context.avatar_public_url = "https://spaces.techub/new-avatar.png"

          result = PersistGithubProfile.call(context: context)

          assert result.success?, -> { result.error&.message }
          assert_equal "https://spaces.techub/new-avatar.png", @profile.reload.avatar_url
        end

        test "preserve_profile_fields keeps manual values" do
          @profile.update!(name: "Custom Name", bio: "Custom Bio")
          context = build_context(overrides: { preserve_profile_fields: [ :name, "bio" ] })
          payload = github_payload
          payload[:profile] = payload[:profile].merge(
            name: "GitHub Name",
            bio: "New Bio"
          )
          context.github_payload = payload

          result = PersistGithubProfile.call(context: context)

          assert result.success?, -> { result.error&.message }
          @profile.reload
          assert_equal "Custom Name", @profile.name
          assert_equal "Custom Bio", @profile.bio
        end

        private

        def build_context(overrides: {})
          Profiles::Pipeline::Context.new(
            login: @profile.login,
            host: "http://example.com",
            overrides: overrides
          )
        end

        def github_payload
          {
            profile: {
              id: @profile.github_id,
              login: @profile.login,
              name: @profile.name,
              followers: 1,
              following: 0,
              public_repos: 0,
              public_gists: 0,
              bio: "Hi",
              company: nil,
              location: nil,
              blog: nil,
              twitter_username: nil,
              hireable: false,
              html_url: "https://github.com/#{@profile.login}",
              created_at: Time.current - 5.years,
              updated_at: Time.current
            },
            summary: "Summary",
            top_repositories: [],
            pinned_repositories: [],
            active_repositories: [],
            organizations: [],
            social_accounts: [],
            languages: []
          }
        end
      end
    end
  end
end
