require "test_helper"

class Profiles::Pipeline::ContextTraceRobustnessTest < ActiveSupport::TestCase
  test "trace handles non-hash payload gracefully" do
    context = Profiles::Pipeline::Context.new(login: "testuser", host: "https://example.com")

    # Test with a string payload (should not crash)
    assert_nothing_raised do
      context.trace(:test_stage, :event, "invalid_string_payload")
    end

    # Verify trace was still recorded
    assert_equal 1, context.trace_entries.length
    entry = context.trace_entries.first
    assert_equal "test_stage", entry[:stage]
    assert_equal "event", entry[:event]
    assert entry[:run_id].present?
  end

  test "trace handles hash with nil values correctly" do
    context = Profiles::Pipeline::Context.new(login: "testuser", host: "https://example.com")

    # Test with a hash containing nil values
    assert_nothing_raised do
      context.trace(:test_stage, :event, { error: "test error", details: nil, count: 5 })
    end

    # Verify nil values were removed via compact
    entry = context.trace_entries.first
    assert_equal "test error", entry[:error]
    assert_equal 5, entry[:count]
    assert entry[:run_id].present?
    assert_nil entry[:details]  # Should not be present after compact
  end

  test "trace handles payload with objects that don't serialize well" do
    context = Profiles::Pipeline::Context.new(login: "testuser", host: "https://example.com")

    # Create a custom object that might cause issues
    bad_object = Object.new

    # Test with a hash containing the bad object
    assert_nothing_raised do
      context.trace(:test_stage, :event, { error: "test", bad_value: bad_object })
    end

    # Verify trace was still recorded
    assert_equal 1, context.trace_entries.length
    assert context.trace_entries.first[:run_id].present?
  end

  test "trace continues to work after an error in one call" do
    context = Profiles::Pipeline::Context.new(login: "testuser", host: "https://example.com")

    # First call with potentially problematic data
    context.trace(:stage1, :event1, "invalid")

    # Second call with valid data should still work
    context.trace(:stage2, :event2, { status: "success" })

    # Both should be recorded
    assert_equal 2, context.trace_entries.length
    first_entry, second_entry = context.trace_entries
    assert_equal "stage1", first_entry[:stage]
    assert_equal "stage2", second_entry[:stage]
    assert_equal "success", second_entry[:status]
    assert first_entry[:run_id].present?
    assert_equal first_entry[:run_id], second_entry[:run_id]
  end
end
