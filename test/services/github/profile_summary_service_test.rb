require "test_helper"

module Github
  class ProfileSummaryServiceTest < ActiveSupport::TestCase
    test "builds summary payload from client data" do
      user_payload = {
        id: 1,
        login: "loftwah",
        name: "Dean Lofts",
        avatar_url: "https://github.com/loftwah.png",
        bio: "Rails deployer",
        company: "TecHub",
        location: "Perth",
        blog: "https://techub.dev",
        followers: 22,
        following: 5,
        public_repos: 10,
        public_gists: 2,
        created_at: Time.utc(2014, 1, 1)
      }

      repositories = [
        {
          name: "techub",
          description: "AI cards",
          html_url: "https://github.com/techub",
          stargazers_count: 42,
          forks_count: 3,
          language: "Ruby",
          topics: %w[rails ai],
          fork: false
        },
        {
          name: "other",
          description: nil,
          html_url: "https://github.com/other",
          stargazers_count: 5,
          forks_count: 1,
          language: "TypeScript",
          topics: [],
          fork: false
        }
      ]

      client = Class.new do
        def initialize(user_payload, repositories)
          @user_payload = user_payload
          @repositories = repositories
        end

        def user(_login)
          @user_payload
        end

        def repositories(_login, per_page: 100)
          raise ArgumentError, "per_page expected 100" unless per_page == 100

          @repositories
        end

        def readme(_repo)
          raise Octokit::NotFound
        end

        def user_events(_login, per_page: 100)
          []
        end

        def post(_path, _body)
          { data: { user: { pinnedItems: { nodes: [] } } } }
        end

        def repository(_full_name)
          raise Octokit::NotFound
        end

        def organizations(_login)
          []
        end
      end.new(user_payload, repositories)

      result = Github::ProfileSummaryService.call(login: "loftwah", client: client)

      assert result.success?
      payload = result.value
      assert_equal user_payload[:bio], payload[:profile][:bio]
      assert_equal "techub", payload[:top_repositories].first[:name]
      assert payload[:summary].include?("42 stars"), "summary should reference top repo"
    end
  end
end
