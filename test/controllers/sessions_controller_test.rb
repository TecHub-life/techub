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

  test "start stores invite_code in session via GET" do
    get auth_github_path(invite_code: "Hunter2 ")

    assert_response :redirect
    assert_equal "Hunter2 ", session[:invite_code]
  end

  test "start stores invite_code in session via POST" do
    post auth_github_path, params: { invite_code: "loftwah" }

    assert_response :redirect
    assert_equal "loftwah", session[:invite_code]
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

  test "callback auto-allows and signs in with valid invite code" do
    get auth_github_path(invite_code: "hunter2")
    state = session[:github_oauth_state]

    user = User.create!(github_id: 2, login: "newuser", access_token: "tok")

    # Force access gate closed and invite code valid; capture add_allowed_login
    added = false
    Access::Policy.stub :allowed?, false do
      Access::InviteCodes.stub :valid?, true do
        Access::Policy.stub :add_allowed_login, ->(login) { added = (login == "newuser") } do
          Github::Configuration.stub :callback_url, auth_github_callback_url do
            Github::UserOauthService.stub :call, ServiceResult.success({ access_token: "abc", scope: "read:user", token_type: "bearer" }) do
              Github::FetchAuthenticatedUser.stub :call, ServiceResult.success({ user: { id: 2, login: "newuser", name: "New", avatar_url: "https://example.com/a.png" }, emails: [] }) do
                Users::UpsertFromGithub.stub :call, ServiceResult.success(user) do
                  get auth_github_callback_path(code: "xyz", state: state)

                  assert_redirected_to root_path
                  assert_equal user.id, session[:current_user_id]
                  assert added, "expected add_allowed_login to be called with newuser"
                end
              end
            end
          end
        end
      end
    end
  end

  test "callback blocks when invite code invalid and user not allowed" do
    get auth_github_path(invite_code: "badcode")
    state = session[:github_oauth_state]

    user = User.create!(github_id: 3, login: "blocked", access_token: "tok")

    Access::Policy.stub :allowed?, false do
      Access::InviteCodes.stub :valid?, false do
        Github::Configuration.stub :callback_url, auth_github_callback_url do
          Github::UserOauthService.stub :call, ServiceResult.success({ access_token: "abc", scope: "read:user", token_type: "bearer" }) do
            Github::FetchAuthenticatedUser.stub :call, ServiceResult.success({ user: { id: 3, login: "blocked", name: "B", avatar_url: "https://example.com/b.png" }, emails: [] }) do
              Users::UpsertFromGithub.stub :call, ServiceResult.success(user) do
                get auth_github_callback_path(code: "xyz", state: state)

                assert_redirected_to root_path
                assert_nil session[:current_user_id]
                assert_nil session[:invite_code], "invite_code should be cleared"
              end
            end
          end
        end
      end
    end
  end
end
