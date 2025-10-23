module Profiles
  module Pipeline
    class Context
      attr_reader :login, :host
      attr_accessor :github_payload, :profile, :avatar_local_path,
                    :scrape, :card, :captures, :optimizations, :eligibility

      def initialize(login:, host:)
        @login = login.to_s.downcase
        @host = host
        @captures = {}
        @optimizations = {}
        @trace = []
      end

      def trace(stage, event, payload = {})
        @trace << {
          stage: stage.to_s,
          event: event.to_s,
          at: Time.current.iso8601(3)
        }.merge(payload.compact)
      end

      def trace_entries
        @trace.dup
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
          github_payload: github_payload,
          profile: profile_snapshot,
          avatar_local_path: avatar_local_path,
          scrape: scrape_snapshot,
          card: card_snapshot,
          captures: captures,
          optimizations: optimizations,
          eligibility: eligibility
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
    end
  end
end
