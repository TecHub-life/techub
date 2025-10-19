require "test_helper"

class GenerateSocialAssetsServiceTest < ActiveSupport::TestCase
  test "output filenames map correctly" do
    svc = Profiles::GenerateSocialAssetsService.new(login: "example")
    mapping = {
      "x_profile_400" => "x-profile-400x400.jpg",
      "x_header_1500x500" => "x-header-1500x500.jpg",
      "x_feed_1600x900" => "x-feed-1600x900.jpg",
      "ig_square_1080" => "ig-square-1080.jpg",
      "ig_portrait_1080x1350" => "ig-portrait-1080x1350.jpg",
      "ig_landscape_1080x566" => "ig-landscape-1080x566.jpg",
      "fb_cover_851x315" => "fb-cover-851x315.jpg",
      "fb_post_1080" => "fb-post-1080x1080.jpg",
      "linkedin_cover_1584x396" => "linkedin-cover-1584x396.jpg",
      "linkedin_profile_400" => "linkedin-profile-400x400.jpg",
      "youtube_cover_2560x1440" => "youtube-cover-2560x1440.jpg",
      "og_1200x630" => "og-1200x630.jpg"
    }

    mapping.each do |kind, expected|
      actual = svc.send(:output_filename_for, kind)
      assert_equal expected, actual, "#{kind} filename mismatch"
    end
  end
end
