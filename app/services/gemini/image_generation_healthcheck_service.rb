module Gemini
  class ImageGenerationHealthcheckService < ApplicationService
    def initialize(project_id: Gemini::Configuration.project_id, location: Gemini::Configuration.location)
      @project_id = project_id
      @location = location
    end

    def call
      client_result = Gemini::ClientService.call(project_id: project_id, location: location)
      return client_result if client_result.failure?

      conn = client_result.value

      # Try Gemini 2.5 Flash Image (nano-banana) via generateContent (png response)
      gen_path = if Gemini::Configuration.provider == "ai_studio"
        "/v1beta/models/#{Gemini::Configuration.image_model}:generateContent"
      else
        "/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{Gemini::Configuration.image_model}:generateContent"
      end
      payload = if Gemini::Configuration.provider == "ai_studio"
        {
          contents: [ { role: "user", parts: [ { text: "Create a small red dot on white" } ] } ],
          generationConfig: { maxOutputTokens: 1, temperature: 0 }
        }
      else
        {
          contents: [ { role: "user", parts: [ { text: "Generate a 32x32 PNG of a red dot on white." } ] } ],
          generationConfig: { maxOutputTokens: 1, temperature: 0 }
        }
      end
      resp = conn.post(gen_path, payload)
      return success({ status: "ok", model: Gemini::Configuration.image_model }, metadata: { http_status: resp.status }) if (200..299).include?(resp.status)

      failure(StandardError.new("Image generation healthcheck failed"), metadata: {
        http_status: resp.status,
        body: resp.body
      })
    rescue Faraday::Error => e
      failure(e)
    end

    private
    attr_reader :project_id, :location
  end
end
