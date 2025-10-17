module Notifications
  class RecordEventService < ApplicationService
    def initialize(user:, event:, subject:)
      @user = user
      @event = event.to_s
      @subject = subject
    end

    def call
      delivery = NotificationDelivery.find_or_initialize_by(
        user_id: user.id,
        event: event,
        subject_type: subject.class.name,
        subject_id: subject.id
      )
      delivery.delivered_at = Time.current
      delivery.save!
      success(delivery)
    rescue StandardError => e
      failure(e)
    end

    private
    attr_reader :user, :event, :subject
  end
end
