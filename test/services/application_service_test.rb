require "test_helper"

class DummyService < ApplicationService
  def initialize(should_fail: false, should_degrade: false)
    @should_fail = should_fail
    @should_degrade = should_degrade
  end

  def call
    return failure("nope") if @should_fail
    return degraded("meh", metadata: { reason: "test" }) if @should_degrade

    success("yep")
  end
end

class ApplicationServiceTest < ActiveSupport::TestCase
  test "call class method delegates to instance" do
    result = DummyService.call

    assert result.success?
    assert_equal "yep", result.value
  end

  test "call handles failures" do
    result = DummyService.call(should_fail: true)

    assert result.failure?
    assert_equal "nope", result.error
    assert_equal :failed, result.status
  end

  test "call handles degraded responses" do
    result = DummyService.call(should_degrade: true)

    assert result.success?
    assert result.degraded?
    assert_equal :degraded, result.status
    assert_equal "meh", result.value
    assert_equal({ reason: "test" }, result.metadata)
  end
end
