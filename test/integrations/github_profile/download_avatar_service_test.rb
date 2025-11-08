require "test_helper"

module GithubProfile
  class DownloadAvatarServiceTest < ActiveSupport::TestCase
    def setup
      @avatars_dir = Rails.root.join("public", "avatars")
      FileUtils.mkdir_p(@avatars_dir)
    end

    def teardown
      Dir.glob(@avatars_dir.join("tester*")) { |path| FileUtils.rm_f(path) }
    end

    test "downloads avatar when response is valid image" do
      url = "https://avatars.example.com/tester.png"
      stub_request(:get, url)
        .to_return(status: 200, body: "png", headers: { "Content-Type" => "image/png", "Content-Length" => "3" })

      Resolv.stub :getaddress, "93.184.216.34" do
        result = GithubProfile::DownloadAvatarService.call(avatar_url: url, login: "tester")

        assert result.success?
        path = Rails.root.join("public", "avatars", "tester.png")
        assert File.exist?(path)
        assert_equal "png", File.binread(path)
      end
    end

    test "rejects non-image content" do
      url = "https://avatars.example.com/tester.txt"
      stub_request(:get, url)
        .to_return(status: 200, body: "nope", headers: { "Content-Type" => "text/plain" })

      Resolv.stub :getaddress, "93.184.216.34" do
        result = GithubProfile::DownloadAvatarService.call(avatar_url: url, login: "tester")
        assert result.failure?
        assert_match(/Invalid content type/, result.error.message)
      end
    end
  end
end
