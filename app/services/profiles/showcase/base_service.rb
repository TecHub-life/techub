module Profiles
  module Showcase
    class BaseService < ApplicationService
      attr_reader :profile, :actor

      def initialize(profile:, actor: nil, **_opts)
        @profile = profile
        @actor = actor
      end

      private

      def boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def integer(value)
        return value if value.is_a?(Integer)
        return nil if value.nil?

        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end

      def normalize_blank(value)
        value.presence
      end

      def parse_date(value)
        return value if value.is_a?(Date)
        return nil if value.blank?

        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def parse_month_to_date(value)
        return nil if value.blank?
        return value if value.is_a?(Date)

        Date.strptime(value.to_s, "%Y-%m")
      rescue ArgumentError
        parse_date(value)
      end

      def parse_timestamp(value, timezone: nil)
        return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
        return nil if value.blank?

        zone = timezone.present? ? ActiveSupport::TimeZone[timezone] : Time.zone
        zone ? zone.parse(value.to_s) : Time.zone.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def total_pinned_count
        profile.profile_links.pinned.count + profile.profile_achievements.pinned.count + profile.profile_experiences.pinned.count
      end

      def can_pin?(previously_pinned)
        return true if previously_pinned

        total_pinned_count < profile.showcase_pin_limit
      end

      def log_action(action, metadata = {})
        return unless defined?(StructuredLogger)

        StructuredLogger.info(
          {
            action: action,
            profile: profile.login,
            actor_id: actor&.id,
            actor_login: actor&.login
          }.merge(metadata)
        )
      end
    end
  end
end
