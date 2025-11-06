require "test_helper"

module Profiles
  module Showcase
    class AchievementUpsertServiceTest < ActiveSupport::TestCase
      test "persists optional url and icon" do
        profile = Profile.create!(github_id: SecureRandom.random_number(100_000), login: "achiever#{SecureRandom.hex(2)}")

        result = AchievementUpsertService.call(
          profile: profile,
          attributes: {
            title: "Won ShipIt",
            url: "https://techub.life/wins",
            fa_icon: "fa-solid fa-medal"
          },
          actor: nil
        )

        assert result.success?, result.error
        achievement = result.value
        assert_equal "https://techub.life/wins", achievement.url
        assert_equal "fa-solid fa-medal", achievement.fa_icon
      end
    end
  end
end
