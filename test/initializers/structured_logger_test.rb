require "test_helper"

class StructuredLoggerTest < ActiveSupport::TestCase
  setup do
    @original_worker = StructuredLogger.const_get(:AXIOM_FORWARD_WORKER)
    @original_pid = StructuredLogger::AXIOM_FORWARD_WORKER_PID.value
  end

  teardown do
    StructuredLogger.send(:remove_const, :AXIOM_FORWARD_WORKER)
    StructuredLogger.const_set(:AXIOM_FORWARD_WORKER, @original_worker)
    StructuredLogger::AXIOM_FORWARD_WORKER_PID.set(@original_pid)
  end

  test "ensure_forward_worker! recreates worker when pid changes" do
    fake_worker = Thread.new { sleep }
    StructuredLogger::AXIOM_FORWARD_WORKER_PID.set(-1)

    StructuredLogger.stub(:spawn_forward_worker, -> { fake_worker }) do
      StructuredLogger.send(:ensure_forward_worker!)
    end

    assert_equal Process.pid, StructuredLogger::AXIOM_FORWARD_WORKER_PID.value
    assert_same fake_worker, StructuredLogger.const_get(:AXIOM_FORWARD_WORKER)
  ensure
    fake_worker.kill if fake_worker&.alive?
    fake_worker.join(0.1) if fake_worker
  end
end
