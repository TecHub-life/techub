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
      options: stage.options
    )
  end

  def redefine_pipeline_stages(stages)
    Profiles::GeneratePipelineService.send(:remove_const, :STAGES)
    Profiles::GeneratePipelineService.const_set(:STAGES, stages.freeze)
  end
end
