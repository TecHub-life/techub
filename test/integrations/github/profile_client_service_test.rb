require "test_helper"
require "base64"

module Github
  class ProfileClientServiceTest < ActiveSupport::TestCase
    class FakeOctokit
      attr_reader :calls

      def initialize
        @calls = []
      end

      def user(login)
        calls << [ :user, login ]
        { "login" => login, "name" => "Test" }
      end

      def repositories(login, per_page: 100)
        calls << [ :repositories, login, per_page ]
        [ { "name" => "repo", "private" => false } ]
      end

      def readme(repo)
        calls << [ :readme, repo ]
        { "content" => Base64.strict_encode64("README") }
      end

      def user_events(login, per_page: 100)
        calls << [ :user_events, login, per_page ]
        [ { "type" => "PushEvent" } ]
      end

      def post(path, body)
        calls << [ :post, path ]
        JSON.parse(body, symbolize_names: true)
      end

      def repository(full_name)
        calls << [ :repository, full_name ]
        { "name" => full_name.split("/").last }
      end

      def organizations(login)
        calls << [ :organizations, login ]
        [ { "login" => "test-org" } ]
      end
    end

    test "wraps octokit client responses" do
      fake = FakeOctokit.new

      Github::AppClientService.stub :call, ServiceResult.success(fake) do
        result = Github::ProfileClientService.call
        assert result.success?

        client = result.value
        user = client.user("loftwah")
        assert_equal "loftwah", user[:login]

        repos = client.repositories("loftwah")
        assert_equal "repo", repos.first[:name]

        readme = client.readme("loftwah/loftwah")
        assert_equal Base64.strict_encode64("README"), readme[:content]

        events = client.user_events("loftwah")
        assert_equal "PushEvent", events.first[:type]

        orgs = client.organizations("loftwah")
        assert_equal "test-org", orgs.first[:login]

        graphql = client.post("/graphql", { query: "{}" }.to_json)
        assert_equal "{}", graphql[:query]
      end
    end

    test "respects injected client" do
      custom = Object.new
      def custom.user(login); { login: login }; end

      result = Github::ProfileClientService.call(client: custom)
      assert result.success?
      assert_equal custom, result.value
    end
  end
end
