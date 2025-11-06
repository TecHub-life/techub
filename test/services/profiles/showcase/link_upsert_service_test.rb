require "test_helper"

module Profiles
  module Showcase
    class LinkUpsertServiceTest < ActiveSupport::TestCase
      test "creates link with defaults" do
        profile = Profile.create!(github_id: SecureRandom.random_number(100_000), login: "tester#{SecureRandom.hex(2)}")

        result = LinkUpsertService.call(
          profile: profile,
          attributes: { label: "Site", url: "https://techub.life", pinned: false },
          actor: nil
        )

        assert result.success?, result.error
        link = result.value
        assert_equal "Site", link.label
        assert_equal "https://techub.life", link.url
        refute link.pinned?
      end

      test "enforces pin limit" do
        profile = Profile.create!(github_id: SecureRandom.random_number(100_000), login: "limit#{SecureRandom.hex(2)}")
        profile.preferences.update!(pin_limit: 1)

        first = LinkUpsertService.call(profile: profile, attributes: { label: "Pinned", pinned: true })
        assert first.success?

        second = LinkUpsertService.call(profile: profile, attributes: { label: "Second", pinned: true })
        assert second.failure?
        assert_match(/Pin limit/, second.error)
      end
    end
  end
end
