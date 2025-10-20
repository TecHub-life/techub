require "base64"

module Gemini
  class ImageGenerationService < ApplicationService
    include Gemini::ResponseHelpers
    DEFAULT_TEMPERATURE = 0.4
    DEFAULT_MIME_TYPE = "image/png".freeze

    def initialize(
      prompt:,
      aspect_ratio:,
      output_path: nil,
      temperature: DEFAULT_TEMPERATURE,
      mime_type: DEFAULT_MIME_TYPE,
      provider: nil
    )
      @prompt = prompt
      @aspect_ratio = aspect_ratio
      @output_path = output_path
      @temperature = temperature
      @mime_type = mime_type
      @provider_override = provider
    end

    def call
      raise ArgumentError, "Prompt cannot be blank" if prompt.blank?
      raise ArgumentError, "Aspect ratio cannot be blank" if aspect_ratio.blank?

      provider = provider_override.presence || Gemini::Configuration.provider

      client_result = Gemini::ClientService.call(provider: provider)
      return client_result if client_result.failure?

      conn = client_result.value
      endpoint = Gemini::Endpoints.image_generate_path(
        provider: provider,
        image_model: Gemini::Configuration.image_model,
        project_id: Gemini::Configuration.project_id,
        location: Gemini::Configuration.location
      )

      # First attempt with provider-specific canonical payload
      payload = build_payload(provider)
      response = conn.post(endpoint, payload)

      unless (200..299).include?(response.status)
        # Auto-recover from provider field-name mismatches by retrying with alternate key
        normalized_body = normalize_to_hash(response.body)
        error_message = dig_value(normalized_body || {}, :error).to_s + response.body.to_s

        retried = false
        if response.status.to_i == 400
          if provider == "vertex" && error_message.include?("responseMimeType")
            alt_payload = build_payload_with_mime_field(provider, :responseMimeType)
            begin
              alt_resp = conn.post(endpoint, alt_payload)
              response = alt_resp
              retried = true
            rescue Faraday::Error
              # fall through to failure
            end
          elsif provider == "ai_studio" && error_message.include?("mimeType")
            alt_payload = build_payload_with_mime_field(provider, :mimeType)
            begin
              alt_resp = conn.post(endpoint, alt_payload)
              response = alt_resp
              retried = true
            rescue Faraday::Error
              # fall through to failure
            end
          end
        end

        unless (200..299).include?(response.status)
          return failure(
            StandardError.new("Gemini image generation failed"),
            metadata: { http_status: response.status, body: response.body, retried_with_alternate_field: retried }
          )
        end
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

    attr_reader :prompt, :aspect_ratio, :output_path, :temperature, :mime_type, :provider_override

    # endpoint computed via Gemini::Endpoints

    def build_payload(provider)
      include_ratio = include_aspect_hint?
      if provider == "vertex"
        cfg = { temperature: temperature }
        cfg[:aspectRatio] = aspect_ratio if include_ratio
        {
          contents: [
            {
              role: "user",
              parts: [
                { text: prompt }
              ]
            }
          ],
          generationConfig: cfg,
          mimeType: mime_type
        }
      else
        cfg = { temperature: temperature }
        cfg[:aspectRatio] = aspect_ratio if include_ratio
        {
          contents: [
            {
              role: "user",
              parts: [
                { text: prompt }
              ]
            }
          ],
          generationConfig: cfg,
          responseMimeType: mime_type
        }
      end
    end

    # Build payload but force a specific field name for output type to maximize compatibility
    def build_payload_with_mime_field(provider, field_name)
      include_ratio = include_aspect_hint?
      cfg = { temperature: temperature }
      cfg[:aspectRatio] = aspect_ratio if include_ratio
      base = {
        contents: [
          {
            role: "user",
            parts: [ { text: prompt } ]
          }
        ],
        generationConfig: cfg
      }
      if field_name.to_s == "mimeType"
        base[:mimeType] = mime_type
      else
        base[:responseMimeType] = mime_type
      end
      base
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

    # normalize_to_hash, dig_value provided by Gemini::ResponseHelpers

    def write_file(decoded_bytes)
      path = Pathname.new(output_path)
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, decoded_bytes)
    end

    def include_aspect_hint?
      flag = ENV["GEMINI_INCLUDE_ASPECT_HINT"].to_s
      return true if flag.blank? # default on
      [ "1", "true", "yes" ].include?(flag.downcase)
    end
  end
end
