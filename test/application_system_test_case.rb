require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  private

  def sign_in_as(user)
    # For system tests, we need to manipulate the session via a controller request
    # This is a workaround since Selenium can't set custom headers

    # Create a temporary session by visiting a page
    visit root_path

    # Use execute_script to set a cookie that the app can read
    # The app checks session[:current_user_id] so we need to set that
    page.execute_script("document.cookie = 'test_user_id=#{user.id}; path=/'")

    # Alternative: Use Capybara's built-in session manipulation
    # This works by adding a cookie that Rails will read
    Capybara.current_session.driver.browser.manage.add_cookie(
      name: "_techub_session",
      value: CGI.escape(ActionDispatch::Session::SessionRestoreError.new.to_s),
      path: "/",
      domain: "127.0.0.1"
    )
  end
end
