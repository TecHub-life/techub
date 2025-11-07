require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTest::ProfileHelpers

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  private

  def sign_in_as(user, redirect_to: root_path)
    raise ArgumentError, "user required" unless user

    visit test_sign_in_path(user_id: user.id, redirect_to: redirect_to)
  end
end
