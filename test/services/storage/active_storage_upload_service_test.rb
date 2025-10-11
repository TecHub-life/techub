require "test_helper"
require "ostruct"

class ActiveStorageUploadServiceTest < ActiveSupport::TestCase
  test "uploads file and returns public url" do
    tmp = Rails.root.join("tmp", "upload_test.png")
    FileUtils.mkdir_p(tmp.dirname)
    File.binwrite(tmp, "\x89PNG\r\n")

    fake_blob = Minitest::Mock.new
    fake_blob.expect(:url, "https://cdn.example.com/abc.png")
    fake_blob.expect(:key, "active-storage-key")
    fake_blob.expect(:filename, OpenStruct.new(to_s: "upload_test.png"))

    ActiveStorage::Blob.stub :create_and_upload!, fake_blob do
      result = Storage::ActiveStorageUploadService.call(path: tmp.to_s, content_type: "image/png")
      assert result.success?, -> { result.error&.message }
      assert_equal "https://cdn.example.com/abc.png", result.value[:public_url]
      assert_equal "active-storage-key", result.value[:key]
      assert_equal "upload_test.png", result.value[:filename]
    end
  ensure
    FileUtils.rm_f(tmp)
  end
end
