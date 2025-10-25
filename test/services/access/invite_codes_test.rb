require "test_helper"

class AccessInviteCodesTest < ActiveSupport::TestCase
  test "codes returns downcased unique list from credentials" do
    creds = { app: { sign_up_codes: [ "Hunter2", " loftwah ", nil, "Loftwah" ] } }
    Rails.application.stub :credentials, creds do
      list = Access::InviteCodes.codes
      assert_equal %w[hunter2 loftwah], list.sort
    end
  end

  test "valid? checks presence in codes case-insensitively" do
    creds = { app: { sign_up_codes: [ "hunter2", "jrh89" ] } }
    Rails.application.stub :credentials, creds do
      assert Access::InviteCodes.valid?("HUNTER2")
      refute Access::InviteCodes.valid?("missing")
    end
  end
end
