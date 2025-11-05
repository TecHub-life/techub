require "test_helper"

class GeneratePipelineServiceTest < ActiveSupport::TestCase
  setup do
    @original_stages = Profiles::GeneratePipelineService::STAGES
  end

  teardown do
    redefine_pipeline_stages(@original_stages)
  end

  test "runs stages in order and returns combined trace" do
    calls = []
    stubbed_stages = Profiles::GeneratePipelineService::STAGES.map do |stage|
      stage_dup(stage, ->(context:, **_) {
        calls << stage.id
        context.trace(stage.id, :stubbed)
        ServiceResult.success(true)
      })
    end
    redefine_pipeline_stages(stubbed_stages)

    result = Profiles::GeneratePipelineService.call(login: "loftwah", host: "http://example.com")

    assert result.success?, -> { result.error&.message }
    assert_equal stubbed_stages.map(&:id), calls
    assert_equal "loftwah", result.value[:login]
    assert_equal "http://example.com", result.metadata[:host]
    assert result.metadata[:run_id].present?
    assert result.metadata[:duration_ms].is_a?(Integer)
    trace_stages = result.metadata[:trace].map { |entry| entry[:stage].to_sym }.uniq
    assert_includes trace_stages, :pipeline
    stubbed_stages.each { |stage| assert_includes trace_stages, stage.id }
  end

  test "halts and returns failure metadata when a stage fails" do
    failing_stage = Profiles::GeneratePipelineService::STAGES.second

    stubbed_stages = Profiles::GeneratePipelineService::STAGES.map do |stage|
      behaviour = if stage == failing_stage
        ->(context:, **_) do
          context.trace(stage.id, :failed, reason: "boom")
          ServiceResult.failure(StandardError.new("boom"), metadata: { reason: "boom" })
        end
      else
        ->(context:, **_) do
          context.trace(stage.id, :stubbed)
          ServiceResult.success(true)
        end
      end

      stage_dup(stage, behaviour)
    end

    redefine_pipeline_stages(stubbed_stages)
    result = Profiles::GeneratePipelineService.call(login: "loftwah")

    assert result.failure?
    assert_equal failing_stage.id, result.metadata[:stage]
    assert_equal "boom", result.metadata[:upstream][:reason]
    stages_in_trace = result.metadata[:trace].map { |entry| entry[:stage].to_sym }
    assert_includes stages_in_trace, failing_stage.id
  end

  test "marks pipeline degraded when a stage degrades" do
    degraded_stage = Profiles::GeneratePipelineService::STAGES.second

    stubbed_stages = Profiles::GeneratePipelineService::STAGES.map do |stage|
      behaviour = if stage == degraded_stage
        ->(context:, **_) do
          context.trace(stage.id, :stubbed)
          ServiceResult.degraded(true, metadata: { reason: "skip" })
        end
      else
        ->(context:, **_) do
          context.trace(stage.id, :stubbed)
          ServiceResult.success(true)
        end
      end

      stage_dup(stage, behaviour)
    end

    redefine_pipeline_stages(stubbed_stages)
    result = Profiles::GeneratePipelineService.call(login: "loftwah")

    assert result.success?
    assert result.degraded?
    assert_equal degraded_stage.id, result.metadata[:degraded_steps].first[:stage]
  end

  test "includes stage metadata and snapshot output" do
    stubbed_stages = Profiles::GeneratePipelineService::STAGES.map do |stage|
      stage_dup(stage, ->(context:, **_) {
        context.trace(stage.id, :stubbed)
        ServiceResult.success({ stage: stage.id }, metadata: { foo: stage.id })
      })
    end
    redefine_pipeline_stages(stubbed_stages)

    result = Profiles::GeneratePipelineService.call(login: "loftwah")

    assert result.success?
    stage_meta = result.metadata[:stage_metadata]
    assert stage_meta.present?
    first_stage = stubbed_stages.first.id
    snapshot_entry = stage_meta[first_stage]
    assert_equal :ok, snapshot_entry[:status]
    assert_equal first_stage, snapshot_entry[:metadata][:foo]

    pipeline_snapshot = result.metadata[:pipeline_snapshot]
    assert pipeline_snapshot[:stages][first_stage].present?
    assert_equal snapshot_entry[:metadata][:foo], pipeline_snapshot[:stages][first_stage][:metadata][:foo]
  end

  test "describe exposes pipeline metadata" do
    description = Profiles::GeneratePipelineService.describe

    assert_equal Profiles::GeneratePipelineService::STAGES.size, description.size
    first = description.first
    assert_includes first.keys, :id
    assert_includes first.keys, :label
    assert_includes first.keys, :service_name
  end

  test "records pipeline events for each stage" do
    login = "loftwah-stage"
    profile = Profile.create!(github_id: 9876, login: login, name: "Lofty Stage")

    stubbed_stages = Profiles::GeneratePipelineService::STAGES.map do |stage|
      stage_dup(stage, ->(context:, **_) {
        context.trace(stage.id, :stubbed)
        ServiceResult.success(true)
      })
    end
    redefine_pipeline_stages(stubbed_stages)

    result = Profiles::GeneratePipelineService.call(login: login)
    assert result.success?

    events = ProfilePipelineEvent.where(profile_id: profile.id).order(:created_at)
    expected_sequence = [ [ :pipeline, "started" ] ]
    stubbed_stages.each do |stage|
      expected_sequence << [ stage.id, "started" ]
      expected_sequence << [ stage.id, "completed" ]
    end
    expected_sequence << [ :pipeline, "completed" ]

    actual = events.map { |event| [ event.stage.to_sym, event.status ] }
    assert_equal expected_sequence, actual
    assert events.where(stage: "pipeline", status: "started").exists?
    assert events.where(stage: "pipeline", status: "completed").exists?
  end

  private

  def stage_dup(stage, proc)
    Profiles::GeneratePipelineService::Stage.new(
      id: stage.id,
      label: stage.label,
      service: Class.new do
        define_singleton_method(:call) do |context:, **options|
          proc.call(context: context, **options)
        end
      end,
      options: stage.options,
      gated_by: stage.gated_by,
      description: stage.description,
      produces: stage.produces
    )
  end

  def redefine_pipeline_stages(stages)
    Profiles::GeneratePipelineService.send(:remove_const, :STAGES)
    Profiles::GeneratePipelineService.const_set(:STAGES, stages.freeze)
  end
end
