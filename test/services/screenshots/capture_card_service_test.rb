require "test_helper"
require "ostruct"

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

  test "fails when node command returns non-zero (stderr captured)" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      status = OpenStruct.new(success?: false)
      Open3.stub :capture3, [ "", "boom", status ] do
        result = Screenshots::CaptureCardService.call(login: "loftwah", variant: "og", host: "http://127.0.0.1:3000")
        assert result.failure?
        assert_includes result.metadata[:stderr], "boom"
      end
    end
  end

  test "og dimensions are 1200x630" do
    result = Screenshots::CaptureCardService.call(login: "loftwah", variant: "og", host: "http://127.0.0.1:3000", output_path: Rails.root.join("tmp", "og-dim.png").to_s)
    assert result.success?
    assert_equal 1200, result.value[:width]
    assert_equal 630, result.value[:height]
  ensure
    FileUtils.rm_f(Rails.root.join("tmp", "og-dim.png"))
  end

  test "builds URL with URI.join" do
    Kernel.stub :system, true do
      out = Rails.root.join("tmp", "url-build.jpg")
      FileUtils.rm_f(out)
      # Create file to simulate success
      File.binwrite(out, "\x00")
      result = Screenshots::CaptureCardService.call(login: "LoFtWaH", variant: "og", host: "http://web", output_path: out.to_s)
      assert result.success?
      assert_match %r{http://web/cards/loftwah/og}, result.value[:url]
    ensure
      FileUtils.rm_f(out)
    end
  end

  test "card dimensions are 1280x720" do
    result = Screenshots::CaptureCardService.call(login: "loftwah", variant: "card", host: "http://127.0.0.1:3000", output_path: Rails.root.join("tmp", "card-dim.png").to_s)
    assert result.success?
    assert_equal 1280, result.value[:width]
    assert_equal 720, result.value[:height]
  ensure
    FileUtils.rm_f(Rails.root.join("tmp", "card-dim.png"))
  end

  test "resolves host via AppHost and enforces production domain" do
    begin
      Object.const_set(:AppHost, Module.new) unless defined?(AppHost)
      AppHost.singleton_class.send(:define_method, :current) { "https://techub.life" }
      result = Screenshots::CaptureCardService.call(login: "loftwah", variant: "og", output_path: Rails.root.join("tmp", "host-test.png").to_s)
      assert result.success?
    ensure
      FileUtils.rm_f(Rails.root.join("tmp", "host-test.png"))
    end
  end

  test "captures stderr when screenshot command fails (explicit)" do
    Rails.stub :env, ActiveSupport::StringInquirer.new("development") do
      status = OpenStruct.new(success?: false)
      Open3.stub :capture3, [ "out", "error details", status ] do
        result = Screenshots::CaptureCardService.call(login: "loftwah", variant: "og", host: "http://127.0.0.1:3000")
        assert result.failure?
        assert_includes result.metadata[:stderr], "error details"
      end
    end
  end
end
