require "test_helper"

module Notifications
  class DeliverOnceServiceTest < ActiveSupport::TestCase
    test "delivers exactly once per user/event/subject" do
      user = User.create!(github_id: 5001, login: "u1", email: "u1@example.com")
      profile = Profile.create!(github_id: 6001, login: "p1")

      sent = 0
      3.times do
        Notifications::DeliverOnceService.call(user: user, event: "pipeline_completed", subject: profile) do
          sent += 1
        end
      end

      assert_equal 1, sent
      assert_equal 1, NotificationDelivery.count
      rec = NotificationDelivery.first
      assert_equal user.id, rec.user_id
      assert rec.delivered_at.present?
    end
  end
end
