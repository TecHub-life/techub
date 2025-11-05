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
      # Optionally create dataset on the fly if missing (guarded by env flag)
      if cfg[:allow_dataset_create]
        begin
          conn.post("/v2/datasets", { name: dataset, description: "techub metrics" })
          retry
        rescue StandardError => e
          ServiceResult.failure(e, metadata: metadata)
        end
      else
        ServiceResult.failure(StandardError.new("dataset_not_found"), metadata: metadata)
      end
    rescue StandardError => e
      ServiceResult.failure(e, metadata: metadata)
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
