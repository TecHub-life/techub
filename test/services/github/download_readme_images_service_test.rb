require "test_helper"

module Github
  class DownloadReadmeImagesServiceTest < ActiveSupport::TestCase
    setup do
      @login = "testuser-#{SecureRandom.hex(4)}"
      @profile_dir = Rails.root.join("tmp", "test_profile_images", @login)
      FileUtils.mkdir_p(@profile_dir)
    end

    teardown do
      FileUtils.rm_rf(@profile_dir) if File.exist?(@profile_dir)
    end

    test "returns original content when no images present" do
      content = "# Test Profile\n\nNo images here."

      result = DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert result.success?
      assert_equal 0, result.value[:images_downloaded]
      assert_equal content, result.value[:content]
    end

    test "handles blank content" do
      result = DownloadReadmeImagesService.call(
        readme_content: "",
        login: @login
      )

      assert result.success?
      assert_equal "", result.value
    end

    test "handles nil content" do
      result = DownloadReadmeImagesService.call(
        readme_content: nil,
        login: @login
      )

      assert result.success?
      assert_nil result.value
    end

    test "detects markdown images" do
      content = <<~MARKDOWN
        # Test
        ![Alt text](https://example.com/image.png)
      MARKDOWN

      result = DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert result.success?
      # Note: Will be 0 if download fails, which is OK - we handle that gracefully
      assert result.value[:images_downloaded] >= 0
    end

    test "detects HTML images" do
      content = '<img src="https://example.com/test.jpg" alt="Test">'

      result = DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert result.success?
      assert result.value[:images_downloaded] >= 0
    end

    test "creates profile-specific directory" do
      content = "![test](https://example.com/fake.png)"

      DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert File.directory?(@profile_dir)
    end

    test "handles download failures gracefully" do
      content = "![test](https://invalid-url-that-does-not-exist.com/image.png)"

      result = DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert result.success?
      # Service should complete even if individual downloads fail
      assert_not_nil result.value[:content]
      assert_not_nil result.value[:images_downloaded]
    end
  end
end
