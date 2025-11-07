require "test_helper"
require "fileutils"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTest::ProfileHelpers

  LOG_PATH = Rails.root.join("tmp/system_tests/selenium.log")
  FileUtils.mkdir_p(LOG_PATH.dirname)
  Selenium::WebDriver.logger.level = :info
  Selenium::WebDriver.logger.output = LOG_PATH

  Capybara.register_driver :selenium_headless do |app|
    chrome_opts = Selenium::WebDriver::Chrome::Options.new
    chrome_opts.binary = ENV["SELENIUM_CHROME_BINARY"] if ENV["SELENIUM_CHROME_BINARY"].present?
    chrome_opts.add_argument("--disable-gpu")
    chrome_opts.add_argument("--no-sandbox")
    chrome_opts.add_argument("--disable-dev-shm-usage")
    chrome_opts.add_argument("--remote-debugging-port=9222")
    chrome_opts.add_argument("--headless=new") unless ENV["HEADLESS"] == "false"
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_opts)
  end

  driven_by :selenium_headless, screen_size: [ 1400, 1400 ]

  private

  def sign_in_as(user, redirect_to: root_path)
    raise ArgumentError, "user required" unless user

    visit test_sign_in_path(user_id: user.id, redirect_to: redirect_to)
  end
end
