require "test_helper"

module Profiles
  class IngestSubmittedRepositoriesServiceTest < ActiveSupport::TestCase
    setup do
      @profile = Profile.create!(github_id: 101, login: "tester", name: "Tester")
      @profile.profile_repositories.create!(full_name: "tester/demo", repository_type: "submitted", name: "demo")
    end

    test "ingests submitted repositories with metadata" do
      fake_repo = Struct.new(:full_name, :name, :description, :html_url, :stargazers_count, :forks_count, :language, :created_at, :updated_at, :topics)
        .new("tester/demo", "demo", "desc", "https://github.com/tester/demo", 5, 1, "Ruby", Time.current, Time.current, [ "rails" ])
      fake_client = Class.new do
        def initialize(repo)
          @repo = repo
        end

        def repository(full_name)
          raise "unexpected" unless full_name == @repo.full_name
          @repo
        end
      end.new(fake_repo)

      result = Profiles::IngestSubmittedRepositoriesService.call(profile: @profile, repo_full_names: [ "tester/demo" ], client: fake_client)

      assert result.success?
      assert_equal 1, result.metadata[:ingested]
      repo = @profile.profile_repositories.find_by(full_name: "tester/demo")
      assert_equal "demo", repo.name
    end

    test "returns degraded when no repositories persist" do
      failing_client = Class.new do
        def repository(_full_name)
          raise StandardError, "boom"
        end
      end.new

      result = Profiles::IngestSubmittedRepositoriesService.call(profile: @profile, repo_full_names: [ "tester/demo" ], client: failing_client)

      assert result.success?
      assert result.degraded?
      assert_equal 0, result.metadata[:ingested]
      assert_equal "no_repos_saved", result.metadata[:reason]
    end

    test "propagates failure when client acquisition fails" do
      Github::AppClientService.stub :call, ServiceResult.failure(StandardError.new("no_client")) do
        result = Profiles::IngestSubmittedRepositoriesService.call(profile: @profile, repo_full_names: [ "tester/demo" ])

        assert result.failure?
        assert_equal "no_client", result.error.message
      end
    end
  end
end
