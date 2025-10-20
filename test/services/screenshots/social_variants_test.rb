require "test_helper"

class SocialVariantsTest < ActiveSupport::TestCase
  test "social variants include expected kinds" do
    kinds = Screenshots::CaptureCardService::SOCIAL_VARIANTS
    %w[
      x_profile_400 x_header_1500x500 x_feed_1600x900
      ig_square_1080 ig_portrait_1080x1350 ig_landscape_1080x566
      fb_post_1080 fb_cover_851x315
      linkedin_profile_400 linkedin_cover_1584x396
      youtube_cover_2560x1440 og_1200x630
    ].each do |k|
      assert_includes kinds, k
    end
  end
end
