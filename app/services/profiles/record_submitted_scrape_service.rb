module Profiles
  class RecordSubmittedScrapeService < ApplicationService
    def initialize(profile:, url:)
      @profile = profile
      @url = url.to_s
    end

    def call
      return failure(StandardError.new("no_profile")) unless profile.is_a?(::Profile)
      return failure(StandardError.new("url_blank")) if url.blank?

      scraped = Scraping::ScrapeUrlService.call(url: url)
      return scraped if scraped.failure?

      data = scraped.value
      meta = scraped.metadata || {}
      status = upsert_scrape!(data, meta)
      success(status)
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :profile, :url

    def upsert_scrape!(data, meta)
      persisted_url = meta[:url].presence || url
      rec = ProfileScrape.find_or_initialize_by(profile_id: profile.id, url: persisted_url)
      rec.assign_attributes(
        title: data[:title],
        description: data[:description],
        canonical_url: data[:canonical_url],
        content_type: meta[:content_type],
        http_status: meta[:http_status] || 200,
        bytes: meta[:bytes] || (data[:text] || "").bytesize,
        fetched_at: Time.current,
        text: data[:text],
        links: data[:links]
      )
      rec.save!
      rec
    end
  end
end
