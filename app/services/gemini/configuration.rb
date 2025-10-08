module Gemini
  class Configuration
    MODEL = "gemini-2.5-flash".freeze

    class << self
      def model
        MODEL
      end

      # Provider selector: "vertex" (default) or "ai_studio"
      def provider
        (ENV["GEMINI_PROVIDER"].presence || cred_lookup([ :gemini, :provider ], [ :google, :gemini, :provider ]) || "vertex").to_s
      end

      # Vertex settings
      def project_id
        ENV["GOOGLE_CLOUD_PROJECT"].presence || cred_lookup([ :gemini, :project_id ], [ :google, :project_id ])
      end

      def location
        ENV["GEMINI_LOCATION"].presence || cred_lookup([ :gemini, :location ], [ :google, :location ]) || "us-central1"
      end

      # AI Studio settings
      def api_key
        ENV["GEMINI_API_KEY"].presence || cred_lookup([ :gemini, :api_key ], [ :google, :ai_studio, :api_key ])
      end

      def api_base
        ENV["GEMINI_API_BASE"].presence || cred_lookup([ :gemini, :api_base ], [ :google, :ai_studio, :api_base ]) || "https://generativelanguage.googleapis.com/v1beta"
      end

      # Optional: Application Default Credentials path for Vertex
      def application_credentials_path
        ENV["GOOGLE_APPLICATION_CREDENTIALS"].presence || cred_lookup([ :google, :application_credentials_path ])
      end

      # Optional: JSON content for credentials (if you inject key material directly)
      def application_credentials_json
        cred_lookup([ :google, :application_credentials_json ])
      end

      # Validates that required config is present for the selected provider
      def validate!
        case provider
        when "vertex"
          # Vertex can work with GCE/GKE/GCloud ADC without explicit file; require project_id at minimum
          raise KeyError, "Missing Gemini configuration for project_id" if project_id.blank?
          true
        when "ai_studio"
          raise KeyError, "Missing Gemini API key" if api_key.blank?
          true
        else
          raise KeyError, "Unsupported GEMINI_PROVIDER: #{provider}"
        end
      end

      def reset!
        # no-op for now; present for symmetry and future caching
        true
      end

      private

      def cred_lookup(*paths)
        creds = Rails.application.credentials
        paths.each do |path|
          value = creds.dig(*path)
          return value if value.present?
        end
        nil
      end
    end
  end
end
