require "test_helper"

class OpsAdminControllerAxiomTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  teardown do
    clear_enqueued_jobs
  end

  test "axiom_worker_probe enqueues job with params" do
    assert_enqueued_with(job: Ops::AxiomProbeJob) do
      post ops_axiom_worker_probe_path, params: { force: "1", note: "hello" }
    end
    job = enqueued_jobs.last
    assert_equal true, job[:args].first["force_axiom"]
    assert_equal "ops_panel", job[:args].first["source"]
    assert_equal "hello", job[:args].first["note"]
    assert_redirected_to ops_admin_path(anchor: "ai")
  end
end
