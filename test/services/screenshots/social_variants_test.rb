require "test_helper"

class SocialVariantsTest < ActiveSupport::TestCase
  test "social variants include expected kinds we support via views" do
    kinds = Screenshots::CaptureCardService::SOCIAL_VARIANTS
    %w[
      x_profile_400
      ig_portrait_1080x1350
      fb_post_1080
    ].each do |k|
      assert_includes kinds, k
    end
  end
end
