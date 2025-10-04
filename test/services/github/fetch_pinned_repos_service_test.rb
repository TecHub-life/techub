require "test_helper"

module Github
  class FetchPinnedReposServiceTest < ActiveSupport::TestCase
    test "fetches and serializes pinned repositories from GraphQL API" do
      graphql_response = {
        data: {
          user: {
            pinnedItems: {
              nodes: [
                {
                  name: "awesome-project",
                  description: "An awesome project",
                  url: "https://github.com/user/awesome-project",
                  stargazerCount: 100,
                  forkCount: 20,
                  primaryLanguage: {
                    name: "Ruby"
                  },
                  repositoryTopics: {
                    nodes: [
                      { topic: { name: "rails" } },
                      { topic: { name: "ruby" } }
                    ]
                  },
                  owner: {
                    login: "user"
                  },
                  updatedAt: "2025-10-01T00:00:00Z",
                  createdAt: "2024-01-01T00:00:00Z"
                }
              ]
            }
          }
        }
      }

      client = Class.new do
        def initialize(response)
          @response = response
        end

        def post(path, body)
          raise ArgumentError, "expected /graphql" unless path == "/graphql"
          @response
        end
      end.new(graphql_response)

      result = Github::FetchPinnedReposService.call(login: "user", client: client)

      assert result.success?
      pinned_repos = result.value
      assert_equal 1, pinned_repos.length

      repo = pinned_repos.first
      assert_equal "awesome-project", repo[:name]
      assert_equal "An awesome project", repo[:description]
      assert_equal 100, repo[:stargazers_count]
      assert_equal "Ruby", repo[:language]
      assert_equal [ "rails", "ruby" ], repo[:topics]
    end

    test "returns empty array on error" do
      client = Class.new do
        def post(_path, _body)
          raise Octokit::Error, "API error"
        end
      end.new

      result = Github::FetchPinnedReposService.call(login: "user", client: client)

      assert result.success?
      assert_equal [], result.value
    end
  end
end
