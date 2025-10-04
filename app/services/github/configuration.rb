require "pathname"

module Github
  class Configuration
    REQUIRED_KEYS = %w[GITHUB_APP_ID GITHUB_CLIENT_ID GITHUB_CLIENT_SECRET].freeze

    class << self
      def app_id
        fetch_config(:app_id, env: "GITHUB_APP_ID", required: true)
      end

      def client_id
        fetch_config(:client_id, env: "GITHUB_CLIENT_ID", required: true)
      end

      def client_secret
        fetch_config(:client_secret, env: "GITHUB_CLIENT_SECRET", required: true)
      end

      def installation_id
        value = fetch_config(:installation_id, env: "GITHUB_INSTALLATION_ID")
        value.present? ? value.to_i : nil
      end

      def webhook_secret
        fetch_config(:webhook_secret, env: "GITHUB_WEBHOOK_SECRET")
      end

      def private_key
        @private_key ||= begin
          key = fetch_config(:private_key, env: "GITHUB_PRIVATE_KEY")
          return normalize_multiline(key) if key.present?

          path = fetch_config(:private_key_path, env: "GITHUB_PRIVATE_KEY_PATH")
          raise KeyError, "Configure github.private_key or github.private_key_path (or set GITHUB_PRIVATE_KEY*)" if path.blank?

          read_private_key(path)
        end
      end

      def reset!
        @private_key = nil
      end

      private

      def fetch_config(credential_key, env:, required: false)
        value = ENV[env].presence || Rails.application.credentials.dig(:github, credential_key)
        if required && value.blank?
          raise KeyError, "Missing GitHub configuration for #{credential_key}"
        end
        value
      end

      def read_private_key(path)
        expanded = Pathname.new(path)
        expanded = Rails.root.join(path) unless expanded.absolute?
        File.read(expanded)
      end

      def normalize_multiline(input)
        input.to_s.gsub(/?
/, "
")
      end
    end
  end
end
