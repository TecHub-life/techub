require "test_helper"

class OptimizeServiceTest < ActiveSupport::TestCase
  test "optimizes png in test env by copying" do
    src = Rails.root.join("tmp", "opt-src.png")
    dst = Rails.root.join("tmp", "opt-out.png")
    FileUtils.mkdir_p(src.dirname)
    File.binwrite(src, "\x89PNG\r\n")

    result = Images::OptimizeService.call(path: src.to_s, output_path: dst.to_s)
    assert result.success?, -> { result.error&.message }
    assert File.exist?(dst)
    assert_equal dst.to_s, result.value[:output_path]
    assert_equal "png", result.value[:format]
  ensure
    FileUtils.rm_f(src)
    FileUtils.rm_f(dst)
  end
end
