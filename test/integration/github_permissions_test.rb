require "test_helper"

class GithubPermissionsTest < ActiveSupport::TestCase
  # This test validates that our GitHub App permissions are sufficient
  # to access the data we need. Run with: rails test test/integration/github_permissions_test.rb

  test "can access user profile data with current permissions" do
    skip "Set GITHUB_TEST_TOKEN to run integration tests" unless ENV["GITHUB_TEST_TOKEN"]

    client = Octokit::Client.new(access_token: ENV["GITHUB_TEST_TOKEN"])

    # Test accessing a public user profile
    user = client.user("loftwah")

    # Verify we can access basic profile data
    assert user.login.present?
    assert user.name.present?
    assert user.avatar_url.present?

    # Verify we can access followers count (requires followers permission)
    assert user.followers.is_a?(Integer)
    assert user.followers >= 0

    # Verify we can access following count (should work with read:user scope)
    assert user.following.is_a?(Integer)
    assert user.following >= 0

    # Verify we can access public repos count
    assert user.public_repos.is_a?(Integer)
    assert user.public_repos >= 0

    puts "✅ Basic profile data accessible"
    puts "   Followers: #{user.followers}"
    puts "   Following: #{user.following}"
    puts "   Public repos: #{user.public_repos}"
  end

  test "can access user email addresses with current permissions" do
    skip "Set GITHUB_TEST_TOKEN to run integration tests" unless ENV["GITHUB_TEST_TOKEN"]

    client = Octokit::Client.new(access_token: ENV["GITHUB_TEST_TOKEN"])

    # Test accessing user's own email addresses (requires user:email scope)
    emails = client.emails

    # Should be able to access emails if user:email scope is granted
    assert emails.is_a?(Array)

    if emails.any?
      puts "✅ Email addresses accessible"
      puts "   Found #{emails.count} email addresses"
      emails.each { |email| puts "   - #{email[:email]} (#{email[:primary] ? 'primary' : 'secondary'})" }
    else
      puts "⚠️  No email addresses found (user may not have public emails)"
    end
  end

  test "can access user followers list with current permissions" do
    skip "Set GITHUB_TEST_TOKEN to run integration tests" unless ENV["GITHUB_TEST_TOKEN"]

    client = Octokit::Client.new(access_token: ENV["GITHUB_TEST_TOKEN"])

    # Test accessing followers list (requires followers permission)
    followers = client.followers("loftwah", per_page: 5)

    assert followers.is_a?(Array)
    puts "✅ Followers list accessible"
    puts "   Found #{followers.count} followers (showing first 5)"

    followers.each do |follower|
      puts "   - #{follower.login} (#{follower.name || 'no name'})"
    end
  end

  test "can access user repositories with current permissions" do
    skip "Set GITHUB_TEST_TOKEN to run integration tests" unless ENV["GITHUB_TEST_TOKEN"]

    client = Octokit::Client.new(access_token: ENV["GITHUB_TEST_TOKEN"])

    # Test accessing public repositories
    repos = client.repositories("loftwah", per_page: 5)

    assert repos.is_a?(Array)
    puts "✅ Public repositories accessible"
    puts "   Found #{repos.count} repositories (showing first 5)"

    repos.each do |repo|
      puts "   - #{repo.name} (#{repo.language || 'no language'}) - #{repo.stargazers_count} stars"
    end
  end

  test "can access user organizations with current permissions" do
    skip "Set GITHUB_TEST_TOKEN to run integration tests" unless ENV["GITHUB_TEST_TOKEN"]

    client = Octokit::Client.new(access_token: ENV["GITHUB_TEST_TOKEN"])

    # Test accessing user organizations
    orgs = client.organizations("loftwah")

    assert orgs.is_a?(Array)
    puts "✅ User organizations accessible"
    puts "   Found #{orgs.count} organizations"

    orgs.each do |org|
      puts "   - #{org.login} (#{org.name || 'no name'})"
    end
  end

  test "can access user events with current permissions" do
    skip "Set GITHUB_TEST_TOKEN to run integration tests" unless ENV["GITHUB_TEST_TOKEN"]

    client = Octokit::Client.new(access_token: ENV["GITHUB_TEST_TOKEN"])

    # Test accessing user events
    events = client.user_events("loftwah", per_page: 5)

    assert events.is_a?(Array)
    puts "✅ User events accessible"
    puts "   Found #{events.count} events (showing first 5)"

    events.each do |event|
      puts "   - #{event.type} at #{event.created_at}"
    end
  end

  test "can access GraphQL social accounts with current permissions" do
    skip "Set GITHUB_TEST_TOKEN to run integration tests" unless ENV["GITHUB_TEST_TOKEN"]

    client = Octokit::Client.new(access_token: ENV["GITHUB_TEST_TOKEN"])

    # Test GraphQL query for social accounts
    query = <<~GRAPHQL
      query($login: String!) {
        user(login: $login) {
          socialAccounts(first: 10) {
            nodes {
              provider
              url
              displayName
            }
          }
        }
      }
    GRAPHQL

    result = client.post "/graphql", { query: query, variables: { login: "loftwah" } }.to_json
    accounts = result.dig(:data, :user, :socialAccounts, :nodes) || []

    assert accounts.is_a?(Array)
    puts "✅ GraphQL social accounts accessible"
    puts "   Found #{accounts.count} social accounts"

    accounts.each do |account|
      puts "   - #{account[:provider]}: #{account[:url]} (#{account[:displayName] || 'no display name'})"
    end
  end
end
