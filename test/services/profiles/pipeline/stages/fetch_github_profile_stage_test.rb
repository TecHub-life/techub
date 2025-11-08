require "test_helper"
require "ostruct"

class FetchGithubProfileStageTest < ActiveSupport::TestCase
  def setup
    @context = Profiles::Pipeline::Context.new(login: "loftwah", host: "http://127.0.0.1:3000")
  end

  test "falls back to app client when user client fails" do
    calls = []

    failure_result = ServiceResult.failure(StandardError.new("user token expired"))
    success_result = ServiceResult.success({ profile: { id: 99, login: "loftwah" } })

    GithubProfile::ProfileSummaryService.stub :call, ->(login:, client: nil) do
      if client
        calls << :user
        failure_result
      else
        calls << :app
        success_result
      end
    end do
      User.stub :find_by, OpenStruct.new(login: "loftwah", access_token: "secrettoken") do
        Octokit::Client.stub :new, Object.new do
          stage = Profiles::Pipeline::Stages::FetchGithubProfile.new(context: @context)
          result = stage.call

          assert result.success?, -> { result.error&.message }
          assert_equal success_result.value, @context.github_payload
          assert_equal [ :user, :app ], calls
        end
      end
    end
  end
end
