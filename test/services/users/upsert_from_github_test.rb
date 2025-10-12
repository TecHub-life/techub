require "test_helper"

module Users
  class UpsertFromGithubTest < ActiveSupport::TestCase
    test "creates user with encrypted token and picks primary verified email" do
      payload = { id: 1, login: "loftwah", name: "Dean Lofts", avatar_url: "https://github.com/loftwah.png" }
      emails = [
        { email: "secondary@example.com", primary: false, verified: true },
        { email: "primary@Example.com", primary: true, verified: true }
      ]

      result = Users::UpsertFromGithub.call(user_payload: payload, access_token: "secret", emails: emails)

      assert result.success?
      user = result.value
      assert_equal "loftwah", user.login
      assert user.access_token.present?
      assert_equal "primary@example.com", user.email
    end

    test "updates existing user" do
      existing = User.create!(github_id: 1, login: "loftwah", access_token: "old")

      payload = { id: 1, login: "loftwah", name: "Dean Lofts", avatar_url: "https://github.com/loftwah.png" }
      result = Users::UpsertFromGithub.call(user_payload: payload, access_token: "new-token")

      assert result.success?
      assert_equal existing.id, result.value.id
      assert_equal "loftwah", result.value.login
    end
  end
end
