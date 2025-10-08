module Gemini
  class HealthcheckService < ApplicationService
    def initialize(project_id: Gemini::Configuration.project_id, location: Gemini::Configuration.location)
      @project_id = project_id
      @location = location
    end

    def call
      client_result = Gemini::ClientService.call(project_id: project_id, location: location)
      return client_result if client_result.failure?

      conn = client_result.value
      # Perform a minimal generateContent request; this verifies model availability and auth
      gen_path = "/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{Gemini::Configuration.model}:generateContent"
      payload = {
        contents: [ { role: "user", parts: [ { text: "ping" } ] } ],
        generationConfig: { maxOutputTokens: 1, temperature: 0.0 }
      }
      resp = conn.post(gen_path, payload)

      return success({ status: "ok", model: Gemini::Configuration.model }, metadata: { http_status: resp.status }) if (200..299).include?(resp.status)

      failure(StandardError.new("Gemini healthcheck failed: #{resp.status}"), metadata: { http_status: resp.status, body: resp.body })
    rescue Faraday::Error => e
      failure(e)
    end

    private
    attr_reader :project_id, :location
  end
end
