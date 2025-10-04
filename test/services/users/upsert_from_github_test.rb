require "test_helper"

module Users
  class UpsertFromGithubTest < ActiveSupport::TestCase
    test "creates user with encrypted token" do
      payload = { id: 1, login: "loftwah", name: "Dean Lofts", avatar_url: "https://github.com/loftwah.png" }

      result = Users::UpsertFromGithub.call(user_payload: payload, access_token: "secret")

      assert result.success?
      user = result.value
      assert_equal "loftwah", user.login
      assert user.access_token.present?
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
