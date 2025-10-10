require "base64"

module Gemini
  class ImageGenerationService < ApplicationService
    DEFAULT_TEMPERATURE = 0.4
    DEFAULT_MIME_TYPE = "image/png".freeze

    def initialize(
      prompt:,
      aspect_ratio:,
      output_path: nil,
      temperature: DEFAULT_TEMPERATURE,
      mime_type: DEFAULT_MIME_TYPE
    )
      @prompt = prompt
      @aspect_ratio = aspect_ratio
      @output_path = output_path
      @temperature = temperature
      @mime_type = mime_type
    end

    def call
      raise ArgumentError, "Prompt cannot be blank" if prompt.blank?
      raise ArgumentError, "Aspect ratio cannot be blank" if aspect_ratio.blank?

      client_result = Gemini::ClientService.call
      return client_result if client_result.failure?

      conn = client_result.value
      provider = Gemini::Configuration.provider
      response = conn.post(endpoint_path(provider), build_payload(provider))

      unless (200..299).include?(response.status)
        return failure(
          StandardError.new("Gemini image generation failed"),
          metadata: { http_status: response.status, body: response.body }
        )
      end

      image_data = extract_image_data(response.body)
      return failure(StandardError.new("Gemini response did not include image data"), metadata: { body: response.body }) if image_data.blank?

      decoded = Base64.decode64(image_data)
      write_file(decoded) if output_path.present?

      success(
        {
          data: image_data,
          bytes: decoded,
          mime_type: mime_type,
          output_path: output_path&.to_s
        },
        metadata: {
          http_status: response.status,
          provider: provider,
          aspect_ratio: aspect_ratio
        }
      )
    rescue Faraday::Error => e
      failure(e)
    end

    private

    attr_reader :prompt, :aspect_ratio, :output_path, :temperature, :mime_type

    def endpoint_path(provider)
      if provider == "ai_studio"
        "/v1beta/models/#{Gemini::Configuration.image_model}:generateContent"
      else
        project = Gemini::Configuration.project_id
        location = Gemini::Configuration.location
        "/v1/projects/#{project}/locations/#{location}/publishers/google/models/#{Gemini::Configuration.image_model}:generateContent"
      end
    end

    def build_payload(provider)
      payload = {
        contents: [
          {
            role: "user",
            parts: [
              { text: prompt }
            ]
          }
        ],
        responseMimeType: mime_type,
        generationConfig: {
          temperature: temperature
        },
        imageGenerationConfig: {
          aspectRatio: aspect_ratio
        }
      }
      payload.delete(:responseMimeType) if provider == "ai_studio" && !supports_response_mime_type?
      payload
    end

    def supports_response_mime_type?
      true
    end

    def extract_image_data(body)
      data = normalize_to_hash(body)
      return if data.blank?

      candidates = dig_value(data, :candidates)
      return if candidates.blank?

      first_candidate = candidates.first
      content = dig_value(first_candidate, :content)
      return if content.blank?

      parts = dig_value(content, :parts)
      return if parts.blank?

      inline_data = parts.find { |part| dig_value(part, :inlineData) }
      inline = dig_value(inline_data, :inlineData) if inline_data
      dig_value(inline, :data) if inline
    end

    def normalize_to_hash(body)
      return body if body.is_a?(Hash)

      if body.respond_to?(:to_hash)
        body.to_hash
      elsif body.present?
        JSON.parse(body)
      end
    rescue JSON::ParserError
      nil
    end

    def dig_value(source, key)
      return nil unless source.respond_to?(:[])

      source[key] || source[key.to_s]
    end

    def write_file(decoded_bytes)
      path = Pathname.new(output_path)
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, decoded_bytes)
    end
  end
end
