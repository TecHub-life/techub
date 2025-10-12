require "test_helper"

module Scraping
  class ScrapeUrlServiceTest < ActiveSupport::TestCase
    setup do
      WebMock.reset!
    end

    test "successfully scrapes linkarooie page" do
      html = <<~HTML
        <!doctype html>
        <html>
          <head>
            <title>Loftwah Links</title>
            <meta name="description" content="All the links for Loftwah">
            <link rel="canonical" href="/loftwah">
          </head>
          <body>
            <main>
              <h1>Loftwah</h1>
              <p>Welcome to my links page.</p>
              <a href="/foo">Foo</a>
            </main>
          </body>
        </html>
      HTML

      stub_request(:get, "https://linkarooie.com/loftwah").to_return(
        status: 200,
        headers: { "Content-Type" => "text/html; charset=utf-8" },
        body: html
      )

      result = Scraping::ScrapeUrlService.call(url: "https://linkarooie.com/loftwah")
      assert result.success?, "expected success, got failure: #{result.error&.message}"

      payload = result.value
      assert_equal "Loftwah Links", payload[:title]
      assert_equal "All the links for Loftwah", payload[:description]
      assert_equal "https://linkarooie.com/loftwah", payload[:canonical_url]
      assert_includes payload[:links], "https://linkarooie.com/foo"
      assert_includes payload[:text], "Loftwah"
    end

    test "invalid url returns failure" do
      result = Scraping::ScrapeUrlService.call(url: "not a url")
      assert result.failure?
      assert_equal "invalid_url", result.error.message
    end

    test "blocks localhost and private addresses" do
      result = Scraping::ScrapeUrlService.call(url: "http://localhost:3000")
      assert result.failure?
      assert_equal "private_address_blocked", result.error.message
    end

    test "fails on unsupported content type" do
      stub_request(:get, "https://linkarooie.com/file.bin").to_return(
        status: 200,
        headers: { "Content-Type" => "application/octet-stream" },
        body: "\x00\x01\x02"
      )

      result = Scraping::ScrapeUrlService.call(url: "https://linkarooie.com/file.bin")
      assert result.failure?
      assert_equal "unsupported_content_type", result.error.message
    end

    test "follows redirects up to limit" do
      stub_request(:get, "https://linkarooie.com/loftwah").to_return(
        status: 301,
        headers: { "Location" => "/home" }
      )

      stub_request(:get, "https://linkarooie.com/home").to_return(
        status: 200,
        headers: { "Content-Type" => "text/html" },
        body: "<html><head><title>Home</title></head><body><main>ok</main></body></html>"
      )

      result = Scraping::ScrapeUrlService.call(url: "https://linkarooie.com/loftwah")
      assert result.success?
      assert_equal "Home", result.value[:title]
    end
  end
end
