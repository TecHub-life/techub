module Analytics
  class ProfileShowcaseTracker < ApplicationService
    attr_reader :attributes, :user, :visit_token

    def initialize(attributes:, user: nil, visit_token: nil)
      @attributes = attributes || {}
      @user = user
      @visit_token = visit_token
    end

    def call
      record_event
      success(true)
    rescue StandardError => e
      StructuredLogger.warn(message: "analytics.track_failed", error: e.message, event: attributes[:event]) if defined?(StructuredLogger)
      failure(e.message)
    end

    private

    def record_event
      return unless defined?(Ahoy::Event)

      Ahoy::Event.create!(
        name: attributes[:event],
        properties: filtered_properties,
        visit_token: visit_token,
        user: user,
        time: Time.current
      )
      StructuredLogger.info({ message: "analytics.track", event: attributes[:event], properties: filtered_properties, user_id: user&.id }, component: "analytics") if defined?(StructuredLogger)
    end

    def filtered_properties
      attributes.slice(:profile, :item_id, :kind, :pinned, :hidden, :style, :surface).compact
    end
  end
end
