require "test_helper"

class CaptureCardServiceTest < ActiveSupport::TestCase
  test "builds command and reports success when file exists" do
    login = "loftwah"
    out = Rails.root.join("tmp", "og-test.png")
    FileUtils.rm_f(out)

    # Stub system to simulate node success
    Kernel.stub :system, true do
      # Create the file as if puppeteer wrote it
      FileUtils.mkdir_p(out.dirname)
      File.binwrite(out, "\x89PNG\r\n")
      result = Screenshots::CaptureCardService.call(login: login, variant: "og", host: "http://127.0.0.1:3000", output_path: out.to_s)
      assert result.success?, -> { result.error&.message }
      assert_equal out.to_s, result.value[:output_path]
      assert_equal "image/png", result.value[:mime_type]
    end
  ensure
    FileUtils.rm_f(out)
  end

  test "fails when system returns false" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      Kernel.stub :system, false do
        result = Screenshots::CaptureCardService.call(login: "loftwah", variant: "og", host: "http://127.0.0.1:3000")
        assert result.failure?
      end
    end
  end
end
