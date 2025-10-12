class NotificationDelivery < ApplicationRecord
  belongs_to :user

  validates :event, :subject_type, :subject_id, presence: true
end
