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

  test "limit uses AppSetting with default 50" do
    AppSetting.delete_all
    assert_equal 50, Access::InviteCodes.limit

    AppSetting.set(:invite_cap_limit, "75")
    assert_equal 75, Access::InviteCodes.limit
  end

  test "used_count reads AppSetting and defaults to 0" do
    AppSetting.delete_all
    assert_equal 0, Access::InviteCodes.used_count

    AppSetting.set(:invite_cap_used, "12")
    assert_equal 12, Access::InviteCodes.used_count
  end

  test "exhausted? compares used_count against limit" do
    AppSetting.delete_all
    AppSetting.set(:invite_cap_limit, "2")
    AppSetting.set(:invite_cap_used, "2")
    assert Access::InviteCodes.exhausted?

    AppSetting.set(:invite_cap_used, "1")
    refute Access::InviteCodes.exhausted?
  end

  test "consume! returns :invalid when code blank or invalid" do
    Rails.application.stub :credentials, { app: { sign_up_codes: [ "abc" ] } } do
      assert_equal :invalid, Access::InviteCodes.consume!(nil)
      assert_equal :invalid, Access::InviteCodes.consume!("")
      assert_equal :invalid, Access::InviteCodes.consume!("nope")
    end
  end

  test "consume! increments used under cap and returns :ok" do
    AppSetting.delete_all
    AppSetting.set(:invite_cap_limit, "2")
    Rails.application.stub :credentials, { app: { sign_up_codes: [ "abc" ] } } do
      assert_equal 0, Access::InviteCodes.used_count
      assert_equal :ok, Access::InviteCodes.consume!("abc")
      assert_equal 1, Access::InviteCodes.used_count
      assert_equal :ok, Access::InviteCodes.consume!("abc")
      assert_equal 2, Access::InviteCodes.used_count
    end
  end

  test "consume! returns :exhausted at cap and does not increment" do
    AppSetting.delete_all
    AppSetting.set(:invite_cap_limit, "1")
    AppSetting.set(:invite_cap_used, "1")
    Rails.application.stub :credentials, { app: { sign_up_codes: [ "abc" ] } } do
      assert_equal :exhausted, Access::InviteCodes.consume!("abc")
      assert_equal 1, Access::InviteCodes.used_count
    end
  end

  test "codes prefers AppSetting override over credentials" do
    AppSetting.delete_all
    AppSetting.set_json(:sign_up_codes_override, [ "OVR1", "ovr2 ", " " ])
    Rails.application.stub :credentials, { app: { sign_up_codes: [ "creds1", "creds2" ] } } do
      assert_equal %w[ovr1 ovr2], Access::InviteCodes.codes.sort
      assert Access::InviteCodes.valid?("OVR2")
      refute Access::InviteCodes.valid?("creds1")
    end
  end
end
