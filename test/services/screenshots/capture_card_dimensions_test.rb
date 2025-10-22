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
      "ig_portrait_1080x1350" => [ 1080, 1350 ],
      "fb_post_1080" => [ 1080, 1080 ]
    }

    expected.each do |k, (ew, eh)|
      assert_equal ew, w[k], "width mismatch for #{k}"
      assert_equal eh, h[k], "height mismatch for #{k}"
    end
  end
end
