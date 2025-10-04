require "test_helper"

class ServiceResultTest < ActiveSupport::TestCase
  test "success result" do
    result = ServiceResult.success({ message: "ok" }, metadata: { context: "test" })

    assert result.success?
    assert_not result.failure?
    assert_equal({ message: "ok" }, result.value)
    assert_nil result.error
    assert_equal({ context: "test" }, result.metadata)
    assert_equal({ message: "ok" }, result.value!)
  end

  test "failure result" do
    error = StandardError.new("boom")
    result = ServiceResult.failure(error, metadata: { context: "test" })

    assert result.failure?
    assert_not result.success?
    assert_equal error, result.error
    assert_raises(StandardError) { result.value! }
    assert_equal error, result.error!
    assert_equal({ context: "test" }, result.metadata)
  end

  test "with_metadata merges new data" do
    result = ServiceResult.success.with_metadata(context: "initial")

    merged = result.with_metadata(extra: "data")

    assert_equal({ context: "initial", extra: "data" }, merged.metadata)
  end
end
