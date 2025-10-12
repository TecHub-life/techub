module Notifications
  class DeliverOnceService < ApplicationService
    def initialize(user:, event:, subject:)
      @user = user
      @event = event.to_s
      @subject = subject
    end

    def call
      return success(:skipped_no_email) if user.email.blank?
      return success(:skipped_opt_out) if user.notify_on_pipeline == false

      delivery = NotificationDelivery.find_or_initialize_by(
        user_id: user.id,
        event: event,
        subject_type: subject.class.name,
        subject_id: subject.id
      )

      return success(:already_delivered) if delivery.persisted? && delivery.delivered_at.present?

      yield if block_given?

      delivery.delivered_at = Time.current
      delivery.save!
      success(delivery)
    rescue ActiveRecord::RecordNotUnique
      success(:already_delivered)
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :user, :event, :subject
  end
end
