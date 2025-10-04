require "test_helper"

class DummyService < ApplicationService
  def initialize(should_fail: false)
    @should_fail = should_fail
  end

  def call
    return failure("nope") if @should_fail

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
  end
end
