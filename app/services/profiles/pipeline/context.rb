require "securerandom"

module Profiles
  module Pipeline
    class Context
      attr_reader :login, :host, :run_id, :overrides
      attr_accessor :github_payload, :profile,
                    :avatar_local_path, :avatar_relative_path, :avatar_public_url, :avatar_upload_metadata,
                    :scrape, :card, :captures, :optimizations, :eligibility,
                    :degraded_steps, :pipeline_outcome, :pipeline_metadata

      def initialize(login:, host:, run_id: nil, overrides: {})
        @login = login.to_s.downcase
        @host = host
        @captures = {}
        @optimizations = {}
        @trace = []
        @overrides = normalize_overrides(overrides)
        @stage_metadata = {}
        @degraded_steps = []
        @run_id = run_id.presence || SecureRandom.uuid
      end

      def trace(stage, event, payload = {})
        safe_payload = sanitize_trace_payload(stage, event, payload)

        @trace << {
          run_id: run_id,
          stage: stage.to_s,
          event: event.to_s,
          at: Time.current.iso8601(3)
        }.merge(safe_payload)
      rescue StandardError => e
        log_trace_failure(stage, event, e)
        @trace << {
          run_id: run_id,
          stage: stage.to_s,
          event: event.to_s,
          at: Time.current.iso8601(3),
          trace_error: e.message
        }
      end

      def trace_entries
        @trace.dup
      end

      def stage_metadata
        deep_dup(@stage_metadata)
      end

      def record_stage_metadata(stage, data)
        return unless stage

        @stage_metadata[stage.to_sym] = deep_dup(data) if data.present?
      end

      def override(key, default = nil)
        return default if overrides.blank?

        overrides.fetch(key.to_sym, default)
      rescue KeyError
        default
      end

      def result_value
        {
          login: login,
          card_id: card_id,
          screenshots: captures.presence,
          optimizations: optimizations.presence,
          scraped: scrape
        }
      end

      def serializable_snapshot
        {
          login: login,
          host: host,
          run_id: run_id,
          github_payload: github_payload,
          profile: profile_snapshot,
          avatar_local_path: avatar_local_path,
          avatar_relative_path: avatar_relative_path,
          avatar_public_url: avatar_public_url,
          avatar_upload_metadata: avatar_upload_metadata,
          scrape: scrape_snapshot,
          card: card_snapshot,
          captures: captures,
          optimizations: optimizations,
          eligibility: eligibility,
          stages: stage_metadata
        }
      end

      private

      PROFILE_KEYS = %w[
        id github_id login name summary followers following public_repos public_gists avatar_url
        last_synced_at last_pipeline_status last_pipeline_error created_at updated_at
      ].freeze

      CARD_KEYS = %w[
        id title tagline attack defense speed vibe archetype special_move generated_at ai_model prompt_version
      ].freeze

      def profile_snapshot
        return unless profile

        profile.attributes.slice(*PROFILE_KEYS)
      end

      def card_snapshot
        return unless card

        card.attributes.slice(*CARD_KEYS)
      end

      def scrape_snapshot
        return unless scrape
        return scrape.serializable_hash if scrape.respond_to?(:serializable_hash)

        scrape.respond_to?(:attributes) ? scrape.attributes : scrape
      end

      def card_id
        card&.id || profile&.profile_card&.id
      end

      def sanitize_trace_payload(stage, event, payload)
        return {} unless payload.is_a?(Hash)

        payload.compact
      rescue StandardError => e
        log_trace_payload_warning(stage, event, payload, e)
        payload.is_a?(Hash) ? payload : {}
      end

      def log_trace_payload_warning(stage, event, payload, error)
        return unless defined?(StructuredLogger)

        StructuredLogger.warn(
          message: "trace_payload_compact_failed",
          stage: stage&.to_s,
          event: event&.to_s,
          error: error.message,
          payload_class: payload.class.name
        )
      end

      def log_trace_failure(stage, event, error)
        return unless defined?(StructuredLogger)

        StructuredLogger.error(
          message: "trace_failed",
          stage: stage.to_s,
          event: event.to_s,
          error: error.message,
          error_class: error.class.name
        )
      end

      def normalize_overrides(value)
        return {} if value.blank?
        value.respond_to?(:deep_symbolize_keys) ? value.deep_symbolize_keys : value
      rescue StandardError
        {}
      end

      def deep_dup(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), memo| memo[k] = deep_dup(v) }
        when Array
          obj.map { |item| deep_dup(item) }
        else
          begin
            obj.dup
          rescue TypeError
            obj
          end
        end
      end
    end
  end
end
