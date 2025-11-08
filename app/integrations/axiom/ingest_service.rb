module Axiom
  class IngestService
    def self.call(...)
      new(...).call
    end

    def initialize(dataset:, events: [])
      @dataset = dataset.to_s
      @events = Array(events)
    end

    def call
      return ServiceResult.failure(StandardError.new("dataset required")) if dataset.blank?
      return ServiceResult.success(0) if events.empty?

      cfg = AppConfig.axiom
      token = cfg[:token]
      return ServiceResult.failure(StandardError.new("missing_token"), metadata: metadata) if token.to_s.strip.empty?

      base_url = cfg[:base_url] || "https://api.axiom.co"
      conn = Faraday.new(url: base_url) do |f|
        f.request :retry
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
      conn.headers["Authorization"] = "Bearer #{token}"
      resp = conn.post("/v1/datasets/#{dataset}/ingest") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = events.to_json
      end
      ServiceResult.success(resp.status, metadata: metadata.merge(base_url: base_url))
    rescue Faraday::ResourceNotFound
      ServiceResult.failure(StandardError.new("dataset_not_found"), metadata: metadata.merge(base_url: base_url))
    rescue StandardError => e
      ServiceResult.failure(e, metadata: metadata.merge(base_url: base_url))
    end

    private
    attr_reader :dataset, :events

    def metadata
      {
        dataset: dataset,
        event_count: events.size
      }
    end
  end
end
