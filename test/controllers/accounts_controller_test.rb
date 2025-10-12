require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(github_id: 7001, login: "tester", email: "old@example.com")
  end

  test "requires login" do
    get edit_account_path
    assert_response :redirect
    assert_match "/auth/github", @response.redirect_url
  end

  test "updates email and notify_on_pipeline" do
    open_session do |sess|
      sess.get root_path
      sess.request.session[:current_user_id] = @user.id
      sess.patch account_path, params: { user: { email: "New@Example.com", notify_on_pipeline: "0" } }
      assert_equal 302, sess.response.status
      @user.reload
      assert_equal "new@example.com", @user.email
      assert_equal false, @user.notify_on_pipeline
    end
  end
end
