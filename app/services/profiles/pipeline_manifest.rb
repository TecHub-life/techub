module Profiles
  # Read-only manifest describing the pipeline stages, gating, and outputs.
  # Source of truth for behaviour remains GeneratePipelineService; this manifest
  # simply centralises visibility so Ops/devs can see the whole flow in one place.
  class PipelineManifest
    STAGE_KEYS = %i[id label gated_by description produces].freeze

    def self.stages
      Profiles::GeneratePipelineService.describe.map do |stage|
        stage.slice(*STAGE_KEYS)
      end
    end

    # Evaluate which stages are presently enabled based on FeatureFlags/AppSetting.
    def self.evaluated
      stages.map do |stage|
        gate = stage[:gated_by]
        enabled = gate.nil? ? true : FeatureFlags.enabled?(gate)
        stage.merge(enabled: enabled)
      end
    end
  end
end
