module Github
  class ProfileClientService < ApplicationService
    def initialize(client: nil)
      @client = client
    end

    def call
      return success(client) if client

      client_result = Github::AppClientService.call
      return client_result if client_result.failure?

      success(ProfileClient.new(client_result.value))
    rescue Octokit::Error => e
      failure(e)
    end

    private

    attr_reader :client

    class ProfileClient
      def initialize(octokit)
        @octokit = octokit
      end

      def user(login)
        to_plain(octokit.user(login))
      end

      def repositories(login, per_page: 100)
        to_plain(octokit.repositories(login, per_page: per_page))
      end

      def readme(repo)
        to_plain(octokit.readme(repo))
      rescue Octokit::NotFound
        raise
      end

      def user_events(login, per_page: 100)
        to_plain(octokit.user_events(login, per_page: per_page))
      end

      def post(path, body)
        to_plain(octokit.post(path, body))
      end

      def repository(full_name)
        to_plain(octokit.repository(full_name))
      end

      def organizations(login)
        to_plain(octokit.organizations(login))
      end

      private

      attr_reader :octokit

      def to_plain(value)
        case value
        when Array
          value.map { |item| to_plain(item) }
        when Hash
          value.deep_symbolize_keys
        else
          if value.respond_to?(:to_h)
            to_plain(value.to_h)
          else
            value
          end
        end
      end
    end
  end
end
