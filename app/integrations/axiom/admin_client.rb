# frozen_string_literal: true

require "json"
require "faraday"

module Axiom
  class AdminClient
    class Error < StandardError
      attr_reader :status, :body

      def initialize(message, status:, body:)
        super(message)
        @status = status
        @body = body
      end
    end

    attr_reader :token, :base_url

    def initialize(token:, base_url: AppConfig::DEFAULT_AXIOM_BASE_URL, connection: nil)
      raise ArgumentError, "token required" if token.to_s.strip.empty?

      @token = token
      @base_url = base_url.presence || AppConfig::DEFAULT_AXIOM_BASE_URL
      @connection = connection || build_connection
    end

    def list_fields(dataset:)
      raise ArgumentError, "dataset required" if dataset.to_s.strip.empty?

      payload = request(:get, "/v2/datasets/#{dataset}/fields")
      normalize_field_list(payload)
    end

    def list_map_fields(dataset:)
      raise ArgumentError, "dataset required" if dataset.to_s.strip.empty?

      request(:get, "/v2/datasets/#{dataset}/mapfields") || []
    end

    def create_map_field(dataset:, name:)
      raise ArgumentError, "dataset required" if dataset.to_s.strip.empty?
      raise ArgumentError, "field name required" if name.to_s.strip.empty?

      request(:post, "/v2/datasets/#{dataset}/mapfields", { name: name })
    end

    def datasets
      request(:get, "/v2/datasets") || []
    end

    def dataset(id:)
      raise ArgumentError, "dataset id required" if id.to_s.strip.empty?

      request(:get, "/v2/datasets/#{id}")
    end

    def create_dataset(name:, description:, retention_days:, kind: nil, use_retention_period: true)
      raise ArgumentError, "name required" if name.to_s.strip.empty?

      body = {
        name: name,
        description: description.to_s,
        retentionDays: retention_days.to_i,
        useRetentionPeriod: !!use_retention_period
      }
      body[:kind] = kind if kind.to_s.present?

      request(:post, "/v2/datasets", body)
    end

    def delete_dataset(id:)
      raise ArgumentError, "dataset id required" if id.to_s.strip.empty?

      request(:delete, "/v2/datasets/#{id}", nil, parse: false)
      true
    end

    def trim_dataset(dataset:, max_duration:, max_time: nil)
      raise ArgumentError, "dataset required" if dataset.to_s.strip.empty?
      raise ArgumentError, "max_duration required" if max_duration.to_s.strip.empty?

      body = { maxDuration: max_duration }
      body[:maxTime] = max_time if max_time.present?

      request(:post, "/v2/datasets/#{dataset}/trim", body, parse: false)
      true
    end

    def vacuum_dataset(dataset:)
      raise ArgumentError, "dataset required" if dataset.to_s.strip.empty?

      request(:post, "/v2/datasets/#{dataset}/vacuum", nil, parse: false)
      true
    end

    private

    attr_reader :connection

    def build_connection
      Faraday.new(url: base_url) do |f|
        f.request :retry
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end.tap do |conn|
        conn.headers["Authorization"] = "Bearer #{token}"
        conn.headers["Content-Type"] = "application/json"
      end
    end

    def request(verb, path, body = nil, parse: true)
      response = connection.public_send(verb) do |req|
        req.url(path)
        req.body = JSON.generate(body) if body
      end
      return nil unless parse

      parse_json(response.body)
    rescue Faraday::ClientError => e
      status = e.response&.fetch(:status, nil)
      body = e.response&.fetch(:body, nil)
      raise Error.new("Axiom admin API error (#{status})", status: status, body: body)
    end

    def parse_json(body)
      return {} if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError => e
      raise Error.new("Invalid JSON from Axiom admin API", status: nil, body: body), cause: e
    end

    def normalize_field_list(payload)
      return [] if payload.blank?

      case payload
      when Array
        payload
      when Hash
        data = payload["data"] || payload["items"] || payload.values.find { |value| value.is_a?(Array) }
        data.is_a?(Array) ? data : []
      else
        []
      end
    end
  end
end
