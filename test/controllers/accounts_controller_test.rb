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
    uid = User.find_by(login: "tester").id
    open_session do |sess|
      sess.patch account_path, params: { user: { email: "New@Example.com", notify_on_pipeline: "0" } }, headers: { "X-Test-User-Id" => uid.to_s }
      assert_equal 302, sess.response.status
      @user.reload
      assert_equal "new@example.com", @user.email
      assert_equal false, @user.notify_on_pipeline
    end
  end
end
