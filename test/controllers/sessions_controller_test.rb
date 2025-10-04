require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["GITHUB_CLIENT_ID"] = "client"
    Github::Configuration.reset!
  end

  teardown do
    ENV.delete("GITHUB_CLIENT_ID")
    Github::Configuration.reset!
  end

  test "start redirects to github" do
    get auth_github_path

    assert_response :redirect
    assert_match "https://github.com/login/oauth/authorize", @response.redirect_url
    assert session[:github_oauth_state].present?
  end

  test "callback signs in user" do
    get auth_github_path
    state = session[:github_oauth_state]

    user = User.create!(github_id: 1, login: "loftwah", access_token: "token")

    Github::Configuration.stub :callback_url, auth_github_callback_url do
      Github::UserOauthService.stub :call, ServiceResult.success({ access_token: "abc", scope: "read:user", token_type: "bearer" }) do
        Github::FetchAuthenticatedUser.stub :call, ServiceResult.success({ user: { id: 1, login: "loftwah", name: "Lofty", avatar_url: "https://github.com/loftwah.png" }, emails: [] }) do
          Users::UpsertFromGithub.stub :call, ServiceResult.success(user) do
            get auth_github_callback_path(code: "xyz", state: state)

            assert_redirected_to root_path
            assert_equal user.id, session[:current_user_id]
          end
        end
      end
    end
  end
end
