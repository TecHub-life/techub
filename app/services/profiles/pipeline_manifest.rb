module Profiles
  # Read-only manifest describing the pipeline stages, gating, and outputs.
  # Source of truth for behaviour remains GeneratePipelineService; this manifest
  # simply centralises visibility so Ops/devs can see the whole flow in one place.
  class PipelineManifest
    Stage = Struct.new(:id, :label, :gated_by, :description, :produces, keyword_init: true)

    def self.stages
      [
        Stage.new(
          id: :sync_from_github,
          label: "Sync from GitHub",
          gated_by: nil,
          description: "Fetch/refresh profile, repos, orgs, activity, readme, and avatar",
          produces: %w[profile profile_repositories profile_organizations profile_activity profile_readme]
        ),
        Stage.new(
          id: :eligibility_gate,
          label: "Eligibility Gate",
          gated_by: :require_profile_eligibility,
          description: "Optionally block pipeline for low-signal profiles",
          produces: []
        ),
        Stage.new(
          id: :ingest_submitted_repositories,
          label: "Ingest Submitted Repositories",
          gated_by: nil,
          description: "Include user-submitted repos into signals",
          produces: [ "profile_repositories(submitted)" ]
        ),
        Stage.new(
          id: :scrape_submitted_url,
          label: "Scrape Submitted URL",
          gated_by: nil,
          description: "Optional scrape of a provided URL to augment signals",
          produces: [ "profile_scrapes(optional)" ]
        ),
        Stage.new(
          id: :ai_traits,
          label: "AI Text & Traits",
          gated_by: :ai_text,
          description: "Structured JSON describing bios, stats, vibe, tags, playing card, archetype, spirit animal",
          produces: [ "profile_card" ]
        ),
        Stage.new(
          id: :base_screenshots,
          label: "Base Screenshots",
          gated_by: nil,
          description: "Capture og, card, simple, banner",
          produces: %w[og card simple banner]
        ),
        Stage.new(
          id: :social_screenshots,
          label: "Social Screenshots",
          gated_by: nil,
          description: "Enqueue 11 social targets (X/IG/FB/LinkedIn/YouTube/OG alias)",
          produces: Screenshots::CaptureCardService::SOCIAL_VARIANTS
        )
      ]
    end

    # Evaluate which stages are presently enabled based on FeatureFlags/AppSetting.
    def self.evaluated
      stages.map do |s|
        gate = s.gated_by
        on = gate.nil? ? true : FeatureFlags.enabled?(gate)
        { id: s.id, label: s.label, enabled: on, gated_by: gate, description: s.description, produces: s.produces }
      end
    end
  end
end
