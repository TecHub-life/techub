require "test_helper"

class Profiles::Pipeline::RecipesTest < ActiveSupport::TestCase
  test "screenshot_refresh normalizes variants and preserves list" do
    overrides = Profiles::Pipeline::Recipes.screenshot_refresh(variants: [ "Og", " card " ])

    assert_equal [ :capture_card_screenshots, :optimize_card_images ], overrides[:only_stages]
    assert_equal %w[og card], overrides[:screenshot_variants]
    assert overrides[:preserve_profile_avatar]
  end

  test "screenshot_refresh returns nil when variants blank" do
    overrides = Profiles::Pipeline::Recipes.screenshot_refresh(variants: [])
    assert_nil overrides
  end

  test "github_sync preserves avatar and default fields" do
    overrides = Profiles::Pipeline::Recipes.github_sync

    assert_equal Profiles::Pipeline::Recipes::GITHUB_CORE, overrides[:only_stages]
    assert_equal Profiles::Pipeline::Recipes::PROFILE_TEXT_FIELDS, overrides[:preserve_profile_fields]
    assert overrides[:preserve_profile_avatar]
  end

  test "avatar_refresh allows avatar overwrite but preserves other fields" do
    overrides = Profiles::Pipeline::Recipes.avatar_refresh

    refute overrides[:preserve_profile_avatar]
    assert_equal Profiles::Pipeline::Recipes::PROFILE_TEXT_FIELDS, overrides[:preserve_profile_fields]
  end
end
