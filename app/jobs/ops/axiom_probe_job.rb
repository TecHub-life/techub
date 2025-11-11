module Ops
  class AxiomProbeJob < ApplicationJob
    queue_as :ops

    def perform(force_axiom: false, source: "ops_panel", note: nil)
      probe_id = SecureRandom.uuid
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      payload = {
        message: "ops_axiom_worker_probe",
        probe_id: probe_id,
        source: source,
        queue: self.class.queue_name,
        host: safe_hostname,
        note: note
      }.compact

      StructuredLogger.info(
        payload.merge(stage: "started"),
        force_axiom: force_axiom,
        component: "worker",
        precedence: "ROUTINE"
      )

      sleep 0.05

      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).to_i
      StructuredLogger.info(
        payload.merge(stage: "completed", duration_ms: duration_ms),
        force_axiom: force_axiom,
        component: "worker",
        precedence: "ROUTINE"
      )
    end

    private

    def safe_hostname
      Socket.gethostname
    rescue StandardError
      nil
    end
  end
end
