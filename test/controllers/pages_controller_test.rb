require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home loads successfully" do
    Github::ProfileSummaryService.stub :call, ServiceResult.failure(StandardError.new("oops")) do
      get root_path
      assert_response :success
    end
  end
end
