module Github
  class FetchPinnedReposService < ApplicationService
    def initialize(login:, client: nil)
      @login = login
      @client = client
    end

    def call
      github_client = client || fetch_client
      return github_client if github_client.is_a?(ServiceResult) && github_client.failure?

      github_client = github_client.value if github_client.is_a?(ServiceResult)

      query = <<~GRAPHQL
        query($login: String!) {
          user(login: $login) {
            pinnedItems(first: 6, types: REPOSITORY) {
              nodes {
                ... on Repository {
                  name
                  description
                  url
                  stargazerCount
                  forkCount
                  primaryLanguage {
                    name
                  }
                  repositoryTopics(first: 10) {
                    nodes {
                      topic {
                        name
                      }
                    }
                  }
                  owner {
                    login
                  }
                  updatedAt
                  createdAt
                }
              }
            }
          }
        }
      GRAPHQL

      result = github_client.post "/graphql", { query: query, variables: { login: login } }.to_json

      pinned_repos = result.dig(:data, :user, :pinnedItems, :nodes) || []

      serialized_repos = pinned_repos.map do |repo|
        {
          name: repo[:name],
          description: repo[:description],
          html_url: repo[:url],
          stargazers_count: repo[:stargazerCount],
          forks_count: repo[:forkCount],
          language: repo.dig(:primaryLanguage, :name),
          topics: repo.dig(:repositoryTopics, :nodes)&.map { |t| t.dig(:topic, :name) } || [],
          owner_login: repo.dig(:owner, :login),
          updated_at: repo[:updatedAt],
          created_at: repo[:createdAt]
        }
      end

      success(serialized_repos)
    rescue => e
      Rails.logger.error("Failed to fetch pinned repos for #{login}: #{e.message}")
      success([]) # Return empty array on failure rather than failing completely
    end

    private

    attr_reader :login, :client

    def fetch_client
      Github::AppClientService.call
    end
  end
end
