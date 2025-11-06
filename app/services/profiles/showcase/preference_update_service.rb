module Profiles
  module Showcase
    class PreferenceUpdateService < BaseService
      attr_reader :attributes

      def initialize(profile:, attributes:, actor: nil)
        super(profile: profile, actor: actor)
        @attributes = attributes || {}
      end

      def call
        record = profile.preferences
        record.assign_attributes(prepared_attributes)

        if record.save
          log_action("preferences.updated", record.attributes.slice("links_sort_mode", "achievements_sort_mode", "experiences_sort_mode"))
          success(record)
        else
          failure(record.errors.full_messages.to_sentence)
        end
      end

      private

      def prepared_attributes
        data = attributes.dup
        if data.key?(:achievements_dual_time)
          data[:achievements_dual_time] = boolean(data[:achievements_dual_time])
        end
        if data.key?(:pin_limit)
          data[:pin_limit] = normalize_pin_limit(data[:pin_limit])
        end
        data
      end

      def normalize_pin_limit(value)
        pin = integer(value)
        return 5 if pin.nil?
        [ [ pin, 1 ].max, 12 ].min
      end
    end
  end
end
