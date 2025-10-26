module Axiom
  class IngestService < ApplicationService
    def initialize(dataset:, events: [])
      @dataset = dataset.to_s
      @events = Array(events)
    end

    def call
      return failure(StandardError.new("dataset required")) if dataset.blank?
      return success(0) if events.empty?

      token = (Rails.application.credentials.dig(:axiom, :token) rescue nil) || ENV["AXIOM_TOKEN"]
      return failure(StandardError.new("missing_token")) if token.to_s.strip.empty?

      base_url = (Rails.application.credentials.dig(:axiom, :base_url) rescue nil) || ENV["AXIOM_BASE_URL"] || "https://api.axiom.co"
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
      success(resp.status)
    rescue Faraday::ResourceNotFound
      # Optionally create dataset on the fly if missing (guarded by env flag)
      if ENV["AXIOM_ALLOW_DATASET_CREATE"] == "1"
        begin
          conn.post("/v2/datasets", { name: dataset, description: "techub metrics" })
          retry
        rescue StandardError => e
          failure(e)
        end
      else
        failure(StandardError.new("dataset_not_found"))
      end
    rescue StandardError => e
      failure(e)
    end

    private
    attr_reader :dataset, :events
  end
end
