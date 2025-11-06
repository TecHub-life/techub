module Profiles
  module Pipeline
    module Recipes
      SCREENSHOT_ONLY = [ :capture_card_screenshots, :optimize_card_images ].freeze
      GITHUB_CORE = [ :pull_github_data, :download_github_avatar, :upload_github_avatar, :store_github_profile, :record_avatar_asset ].freeze
      PROFILE_TEXT_FIELDS = %i[name bio company location blog twitter_username summary].freeze

      module_function

      def screenshot_refresh(variants:, preserve_avatar: true)
        normalized = normalize_variants(variants)
        return nil if normalized.empty?

        {
          only_stages: SCREENSHOT_ONLY,
          screenshot_variants: normalized,
          preserve_profile_avatar: preserve_avatar
        }
      end

      def github_sync(preserve_avatar: true, preserve_fields: PROFILE_TEXT_FIELDS)
        {
          only_stages: GITHUB_CORE,
          preserve_profile_avatar: preserve_avatar,
          preserve_profile_fields: normalize_fields(preserve_fields)
        }
      end

      def avatar_refresh
        github_sync(preserve_avatar: false, preserve_fields: PROFILE_TEXT_FIELDS)
      end

      def normalize_variants(variants)
        Array(variants)
          .map { |variant| variant.to_s.strip.downcase }
          .reject(&:blank?)
          .uniq
      end
      private_class_method :normalize_variants

      def normalize_fields(fields)
        Array(fields)
          .map { |field| field.to_s.strip.downcase }
          .reject(&:blank?)
          .map(&:to_sym)
          .uniq
      end
      private_class_method :normalize_fields
    end
  end
end
