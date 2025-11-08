require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home loads successfully" do
    GithubProfile::ProfileSummaryService.stub :call, ServiceResult.failure(StandardError.new("oops")) do
      get root_path
      assert_response :success
    end
  end

  test "login link is present for signed-out users" do
    GithubProfile::ProfileSummaryService.stub :call, ServiceResult.failure(StandardError.new("oops")) do
      get root_path
      assert_response :success
      assert_match /Sign in/, @response.body
      assert_match /href=\"#{Regexp.escape(login_path)}\"/, @response.body
    end
  end

  test "directory supports multiple tags via CSV" do
    p1 = Profile.create!(github_id: 1, login: "alice", name: "Alice", last_pipeline_status: "success")
    ProfileCard.create!(profile: p1, attack: 10, defense: 10, speed: 10, tags: %w[ruby rails ai js ml data])

    p2 = Profile.create!(github_id: 2, login: "bob", name: "Bob", last_pipeline_status: "success")
    ProfileCard.create!(profile: p2, attack: 10, defense: 10, speed: 10, tags: %w[ruby go ai devops ci cd])

    get directory_path, params: { tags: "ruby, ai" }
    assert_response :success
    assert_match /@alice/, @response.body
    assert_match /@bob/, @response.body

    get directory_path, params: { tags: "rails" }
    assert_response :success
    assert_match /@alice/, @response.body
    assert_no_match /@bob/, @response.body
  end

  test "tag cloud links preserve selection via tags param" do
    Profile.create!(github_id: 3, login: "cara", name: "Cara").tap do |p|
      ProfileCard.create!(profile: p, attack: 10, defense: 10, speed: 10, tags: %w[ruby rails js css html sql])
    end

    get directory_path, params: { tags: "ruby" }
    assert_response :success
    assert_match /tags=ruby/, @response.body
  end
end
