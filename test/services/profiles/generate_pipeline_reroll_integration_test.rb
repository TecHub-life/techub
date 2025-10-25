require "test_helper"

class GeneratePipelineRerollIntegrationTest < ActiveSupport::TestCase
  setup do
    @original_stages = Profiles::GeneratePipelineService::STAGES
  end

  teardown do
    redefine_pipeline_stages(@original_stages)
  end

  test "pipeline continues when submitted scrape url is invalid and runs later stages" do
    login = "reroll-user"
    profile = Profile.create!(github_id: 111222, login: login, name: "Reroll User", submitted_scrape_url: "bad url")

    # Stage 1: set minimal github payload
    fetch_stub = stage_stub(:pull_github_data) do |context:|
      context.github_payload = { profile: { id: profile.github_id, login: profile.login, name: profile.name } }
      ServiceResult.success(true)
    end

    # Stage 2: skip avatar
    avatar_stub = stage_stub(:download_github_avatar) do |context:|
      context.avatar_local_path = nil
      ServiceResult.success(true)
    end

    # Stage 3: persist profile
    persist_stub = stage_stub(:store_github_profile) do |context:|
      # Use real persist stage to ensure profile is set in context
      Profiles::Pipeline::Stages::PersistGithubProfile.call(context: context)
    end

    # Stage 4: eligibility trivial pass
    eligibility_stub = stage_stub(:evaluate_eligibility) do |context:|
      context.eligibility = { eligible: true, score: 10, threshold: 1 }
      ServiceResult.success(true)
    end

    # Stage 5: ingest submitted repos (none)
    ingest_stub = stage_stub(:ingest_submitted_repositories) { |context:| ServiceResult.success(true) }

    # Stage 6: real record_submitted_scrape should SKIP on invalid url instead of failing
    scrape_stage = Profiles::GeneratePipelineService::Stage.new(
      id: :record_submitted_scrape,
      label: "Record submitted scrape",
      service: Profiles::Pipeline::Stages::RecordSubmittedScrape,
      options: {}
    )

    ran_ai = false
    ai_stub = stage_stub(:generate_ai_profile) do |context:|
      ran_ai = true
      context.card = OpenStruct.new(id: 123)
      ServiceResult.success(true)
    end

    ran_caps = false
    caps_stub = Profiles::GeneratePipelineService::Stage.new(
      id: :capture_card_screenshots,
      label: "Capture card screenshots",
      service: Class.new do
        define_singleton_method(:call) do |context:, **|
          context.captures = { "og" => { id: 1 } }
          ServiceResult.success(true)
        end
      end,
      options: { variants: %w[og card] }
    )

    optimize_stub = stage_stub(:optimize_card_images) { |context:| ran_caps = true; ServiceResult.success(true) }

    stages = [ fetch_stub, avatar_stub, persist_stub, eligibility_stub, ingest_stub, scrape_stage, ai_stub, caps_stub, optimize_stub ]
    redefine_pipeline_stages(stages)

    result = Profiles::GeneratePipelineService.call(login: login, host: "http://example.com")
    assert result.success?, -> { result.error&.message }
    assert ran_ai, "expected AI stage to run"
    assert ran_caps, "expected screenshots/optimize stages to run"
  end

  private

  def stage_stub(id, &block)
    Profiles::GeneratePipelineService::Stage.new(
      id: id,
      label: id.to_s.humanize,
      service: Class.new do
        define_singleton_method(:call) do |context:, **options|
          block.call(context: context, **options)
        end
      end,
      options: {}
    )
  end

  def redefine_pipeline_stages(stages)
    Profiles::GeneratePipelineService.send(:remove_const, :STAGES)
    Profiles::GeneratePipelineService.const_set(:STAGES, stages.freeze)
  end
end
