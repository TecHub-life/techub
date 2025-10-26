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

  test "login path redirects to github" do
    get login_path
    assert_response :redirect
    assert_match "https://github.com/login/oauth/authorize", @response.redirect_url
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

  test "signup creates session with invite and optional email then redirects to github" do
    # Valid code and optional email
    Rails.application.stub :credentials, { app: { sign_up_codes: [ "hunter2" ] } } do
      post signup_path, params: { signup: { invite_code: "hunter2", email: "User@Example.com " } }
      assert_response :redirect
      assert_redirected_to auth_github_path
      assert_equal "hunter2", session[:invite_code]
      assert_equal "user@example.com", session[:signup_email]
    end
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

  test "callback applies session email if provided" do
    user = User.create!(github_id: 9, login: "emailuser", access_token: "tok")

    open_session do |sess|
      sess.get auth_github_path
      state = sess.session[:github_oauth_state]
      sess.session[:signup_email] = "emailuser@example.com"

      Github::Configuration.stub :callback_url, auth_github_callback_url do
        Github::UserOauthService.stub :call, ServiceResult.success({ access_token: "abc", scope: "read:user", token_type: "bearer" }) do
          Github::FetchAuthenticatedUser.stub :call, ServiceResult.success({ user: { id: 9, login: "emailuser", name: "E", avatar_url: "https://example.com/e.png" }, emails: [] }) do
            Users::UpsertFromGithub.stub :call, ServiceResult.success(user) do
              Access::Policy.stub :allowed?, true do
                sess.get auth_github_callback_path(code: "xyz", state: state)
                assert_redirected_to root_path
                assert_equal user.id, sess.session[:current_user_id]
                assert_equal "emailuser@example.com", user.reload.email
                assert_nil sess.session[:signup_email]
              end
            end
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
      Access::InviteCodes.stub :consume!, :ok do
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
      Access::InviteCodes.stub :consume!, :invalid do
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

  test "callback blocks with friendly message when invite cap exhausted" do
    get auth_github_path(invite_code: "aa")
    state = session[:github_oauth_state]

    user = User.create!(github_id: 4, login: "exhausted", access_token: "tok")

    Access::Policy.stub :allowed?, false do
      Access::InviteCodes.stub :consume!, :exhausted do
        Github::Configuration.stub :callback_url, auth_github_callback_url do
          Github::UserOauthService.stub :call, ServiceResult.success({ access_token: "abc", scope: "read:user", token_type: "bearer" }) do
            Github::FetchAuthenticatedUser.stub :call, ServiceResult.success({ user: { id: 4, login: "exhausted", name: "E", avatar_url: "https://example.com/e.png" }, emails: [] }) do
              Users::UpsertFromGithub.stub :call, ServiceResult.success(user) do
                get auth_github_callback_path(code: "xyz", state: state)

                assert_redirected_to root_path
                assert_nil session[:current_user_id]
                assert_match /didn't expect this many users/i, flash[:alert]
              end
            end
          end
        end
      end
    end
  end
end
