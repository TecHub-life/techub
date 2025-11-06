require "test_helper"
require "securerandom"

class OgControllerTest < ActionDispatch::IntegrationTest
  setup do
    login = "coder#{SecureRandom.hex(4)}"
    @profile = Profile.create!(
      github_id: SecureRandom.random_number(1_000_000) + 1_000,
      login: login,
      name: "Code R",
      avatar_url: "/avatars/coder.png"
    )
    @generated_dir = Rails.root.join("public", "generated", @profile.login)
    FileUtils.mkdir_p(@generated_dir)
    File.binwrite(@generated_dir.join("og.jpg"), "jpeg")
    File.binwrite(@generated_dir.join("og_pro.jpg"), "jpeg")
  end

  teardown do
    FileUtils.rm_rf(@generated_dir) if @generated_dir
  end

  test "defaults to og variant when no param supplied" do
    get og_image_path(login: @profile.login, format: :jpg)
    assert_response :success
    assert_equal "og", response.headers["X-Techub-Og-Variant"]
  end

  test "serves professional variant when requested" do
    get og_image_path(login: @profile.login, format: :jpg, variant: "og_pro")
    assert_response :success
    assert_equal "og_pro", response.headers["X-Techub-Og-Variant"]
  end
end
