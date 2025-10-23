require "test_helper"
require "tmpdir"

module Profiles
  module Pipeline
    class VerifierTest < ActiveSupport::TestCase
      test "writes per-stage snapshots and artifacts" do
        Dir.mktmpdir do |dir|
          capture_path = Pathname.new(dir).join("source-og.jpg")
          File.write(capture_path, "fake")

          stage1_service = Class.new do
            define_singleton_method(:call) do |context:, **|
              context.github_payload = { profile: { id: 1, login: context.login } }
              context.trace(:stage_one, :completed)
              ServiceResult.success(true, metadata: { step: 1 })
            end
          end

          stage2_service = Class.new do
            define_singleton_method(:call) do |context:, **|
              context.captures = {
                "og" => {
                  local_path: capture_path.to_s,
                  public_url: nil,
                  width: 100,
                  height: 100,
                  mime_type: "image/jpeg",
                  created_at: Time.current,
                  updated_at: Time.current
                }
              }
              context.trace(:stage_two, :completed)
              ServiceResult.success(true, metadata: { step: 2 })
            end
          end

          stages = [
            Profiles::GeneratePipelineService::Stage.new(id: :stage_one, label: "Stage One", service: stage1_service, options: {}),
            Profiles::GeneratePipelineService::Stage.new(id: :stage_two, label: "Stage Two", service: stage2_service, options: {})
          ]

          result = Profiles::Pipeline::Verifier.call(
            login: "tester",
            host: "http://example.com",
            output_dir: dir,
            stages: stages,
            run_pipeline: false
          )

          assert result.success?, -> { result.error&.message }
          assert File.exist?(File.join(dir, "00_initial_context.json"))
          assert File.exist?(File.join(dir, "trace.json"))

          stage_dir = File.join(dir, "01-stage_one")
          assert File.exist?(File.join(stage_dir, "before.json"))
          assert File.exist?(File.join(stage_dir, "after.json"))

          stage2_dir = File.join(dir, "02-stage_two")
          assert File.exist?(File.join(stage2_dir, "result.json"))
          copied_capture = File.join(stage2_dir, "captures", "og.jpg")
          assert File.exist?(copied_capture)

          final_context = JSON.parse(File.read(File.join(dir, "final_context.json")))
          assert_equal "tester", final_context["login"]
          assert_nil result.value[:pipeline], "pipeline summary should be nil when run_pipeline = false"
        end
      end
    end
  end
end
