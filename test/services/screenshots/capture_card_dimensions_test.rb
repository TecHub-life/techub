require "test_helper"

class CaptureCardDimensionsTest < ActiveSupport::TestCase
  test "variant width/height map includes all targets with exact sizes" do
    w = Screenshots::CaptureCardService::DEFAULT_WIDTHS
    h = Screenshots::CaptureCardService::DEFAULT_HEIGHTS

    expected = {
      "og" => [ 1200, 630 ],
      "card" => [ 1280, 720 ],
      "simple" => [ 1280, 720 ],
      "banner" => [ 1500, 500 ],
      "x_profile_400" => [ 400, 400 ],
      "x_header_1500x500" => [ 1500, 500 ],
      "x_feed_1600x900" => [ 1600, 900 ],
      "ig_square_1080" => [ 1080, 1080 ],
      "ig_portrait_1080x1350" => [ 1080, 1350 ],
      "ig_landscape_1080x566" => [ 1080, 566 ],
      "fb_post_1080" => [ 1080, 1080 ],
      "fb_cover_851x315" => [ 851, 315 ],
      "linkedin_profile_400" => [ 400, 400 ],
      "linkedin_cover_1584x396" => [ 1584, 396 ],
      "youtube_cover_2560x1440" => [ 2560, 1440 ],
      "og_1200x630" => [ 1200, 630 ]
    }

    expected.each do |k, (ew, eh)|
      assert_equal ew, w[k], "width mismatch for #{k}"
      assert_equal eh, h[k], "height mismatch for #{k}"
    end
  end
end
