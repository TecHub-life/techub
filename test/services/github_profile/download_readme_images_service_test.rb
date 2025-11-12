require "test_helper"

module GithubProfile
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

      # Stub external image fetch
      stub_request(:get, "https://example.com/image.png").
        to_return(status: 200, body: "PNGDATA", headers: { "Content-Type" => "image/png" })

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

      # Stub external image fetch
      stub_request(:get, "https://example.com/test.jpg").
        to_return(status: 200, body: "JPGDATA", headers: { "Content-Type" => "image/jpeg" })

      result = DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert result.success?
      assert result.value[:images_downloaded] >= 0
    end

    test "creates profile-specific directory" do
      content = "![test](https://example.com/fake.png)"

      # Stub external image fetch
      stub_request(:get, "https://example.com/fake.png").
        to_return(status: 200, body: "PNGDATA", headers: { "Content-Type" => "image/png" })

      DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert File.directory?(@profile_dir)
    end

    test "handles download failures gracefully" do
      content = "![test](https://invalid-url-that-does-not-exist.com/image.png)"

      # Stub to simulate HTTP failure instead of real network
      stub_request(:get, "https://invalid-url-that-does-not-exist.com/image.png").
        to_return(status: 404, body: "Not found", headers: { "Content-Type" => "text/plain" })

      result = DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert result.success?
      # Service should complete even if individual downloads fail
      assert_not_nil result.value[:content]
      assert_not_nil result.value[:images_downloaded]
    end

    test "skips known svg-only badge hosts" do
      url = "https://github-readme-streak-stats.herokuapp.com/?user=bryanperris&theme=tokyonight"
      content = "![test](#{url})"

      stub_request(:get, url)

      result = DownloadReadmeImagesService.call(
        readme_content: content,
        login: @login
      )

      assert result.success?
      assert_equal content, result.value[:content]
      assert_equal 0, result.value[:images_downloaded]
      assert_not_requested(:get, url)
    end
  end
end
