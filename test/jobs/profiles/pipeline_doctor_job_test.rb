require "test_helper"

class Profiles::PipelineDoctorJobTest < ActiveJob::TestCase
  test "performs successfully when doctor service succeeds" do
    login = "loftwah"
    Profile.create!(github_id: 1, login: login)

    Profiles::PipelineDoctorService.stub :call, ServiceResult.success({ ok: true }) do
      assert_nothing_raised do
        Profiles::PipelineDoctorJob.perform_now(login: login, host: "http://example.com", email: nil)
      end
    end
  end
end
