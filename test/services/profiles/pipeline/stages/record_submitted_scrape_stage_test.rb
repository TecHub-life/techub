require "test_helper"

module Profiles
  module Pipeline
    module Stages
      class RecordSubmittedScrapeStageTest < ActiveSupport::TestCase
        setup do
          WebMock.reset!
          @profile = Profile.create!(github_id: 12345, login: "rerolltest")
          @context = Profiles::Pipeline::Context.new(login: @profile.login, host: "http://example.com")
          @context.profile = @profile
        end

        test "skips gracefully when url is bare domain (normalized)" do
          @profile.update!(submitted_scrape_url: "pbsdev.com")

          stub_request(:get, "https://pbsdev.com/").to_return(
            status: 200,
            headers: { "Content-Type" => "text/html; charset=utf-8" },
            body: "<html><head><title>PBS Dev</title></head><body><main>ok</main></body></html>"
          )

          result = Profiles::Pipeline::Stages::RecordSubmittedScrape.call(context: @context)
          assert result.success?, -> { result.error&.message }
        end

        test "non-fatal errors are treated as skip" do
          @profile.update!(submitted_scrape_url: "bad url")
          result = Profiles::Pipeline::Stages::RecordSubmittedScrape.call(context: @context)
          assert result.success?, "expected stage to skip on invalid url"
        end
      end
    end
  end
end
