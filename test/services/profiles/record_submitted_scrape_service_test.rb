require "test_helper"

module Profiles
  class RecordSubmittedScrapeServiceTest < ActiveSupport::TestCase
    setup do
      WebMock.reset!
      @profile = Profile.create!(github_id: 999999, login: "loftwah")
    end

    test "persists scraped content and links" do
      html = <<~HTML
        <html><head>
          <title>Loftwah Links</title>
          <meta name="description" content="All the links for Loftwah">
        </head>
        <body><main>
          <p>Welcome to my links page.</p>
          <a href="https://example.com/a">A</a>
          <a href="/b">B</a>
        </main></body></html>
      HTML

      stub_request(:get, "https://linkarooie.com/loftwah").to_return(
        status: 200,
        headers: { "Content-Type" => "text/html; charset=utf-8" },
        body: html
      )

      result = Profiles::RecordSubmittedScrapeService.call(profile: @profile, url: "https://linkarooie.com/loftwah")
      assert result.success?, "expected success, got failure: #{result.error&.message}"

      rec = ProfileScrape.find_by(profile_id: @profile.id, url: "https://linkarooie.com/loftwah")
      assert rec, "expected a ProfileScrape record"
      assert_equal "Loftwah Links", rec.title
      assert_equal "All the links for Loftwah", rec.description
      assert_includes rec.text, "Welcome to my links page"
      assert_kind_of Array, rec.links
      assert_includes rec.links, "https://example.com/a"
      assert_includes rec.links, "https://linkarooie.com/b"
      assert_equal 200, rec.http_status
      assert_equal "text/html; charset=utf-8", rec.content_type
    end

    test "fails when url is invalid" do
      result = Profiles::RecordSubmittedScrapeService.call(profile: @profile, url: "bad url")
      assert result.failure?
    end
  end
end
