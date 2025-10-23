module Profiles
  # Read-only manifest describing the pipeline stages, gating, and outputs.
  # Source of truth for behaviour remains GeneratePipelineService; this manifest
  # simply centralises visibility so Ops/devs can see the whole flow in one place.
  class PipelineManifest
    Stage = Struct.new(:id, :label, :gated_by, :description, :produces, keyword_init: true)

    def self.stages
      [
        Stage.new(
          id: :pull_github_data,
          label: "Pull GitHub data",
          gated_by: nil,
          description: "Fetch GitHub summary payload (with user-token fallback)",
          produces: %w[github_payload]
        ),
        Stage.new(
          id: :download_github_avatar,
          label: "Download GitHub avatar",
          gated_by: nil,
          description: "Download avatar locally for card usage",
          produces: %w[avatar_local_path]
        ),
        Stage.new(
          id: :store_github_profile,
          label: "Store GitHub profile",
          gated_by: nil,
          description: "Persist profile, repos, orgs, activity, readme, tags",
          produces: %w[profile profile_repositories profile_organizations profile_activity profile_readme]
        ),
        Stage.new(
          id: :evaluate_eligibility,
          label: "Eligibility Gate",
          gated_by: :require_profile_eligibility,
          description: "Optionally block pipeline for low-signal profiles",
          produces: [ "eligibility" ]
        ),
        Stage.new(
          id: :ingest_submitted_repositories,
          label: "Ingest Submitted Repositories",
          gated_by: nil,
          description: "Include user-submitted repos into signals",
          produces: [ "profile_repositories(submitted)" ]
        ),
        Stage.new(
          id: :record_submitted_scrape,
          label: "Scrape Submitted URL",
          gated_by: nil,
          description: "Optional scrape of a provided URL to augment signals",
          produces: [ "profile_scrapes(optional)" ]
        ),
        Stage.new(
          id: :generate_ai_profile,
          label: "Generate AI profile",
          gated_by: :ai_text,
          description: "Structured JSON describing bios, stats, vibe, tags, playing card, archetype, spirit animal",
          produces: [ "profile_card" ]
        ),
        Stage.new(
          id: :capture_card_screenshots,
          label: "Capture card screenshots",
          gated_by: nil,
          description: "Enqueue card, OG, banner, simple, and social targets",
          produces: Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS
        ),
        Stage.new(
          id: :optimize_card_images,
          label: "Optimize card images",
          gated_by: nil,
          description: "Run post-processing and upload-ready optimizations for generated images",
          produces: Profiles::GeneratePipelineService::SCREENSHOT_VARIANTS
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
