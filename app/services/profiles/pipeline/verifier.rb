require "json"
require "fileutils"

module Profiles
  module Pipeline
    class Verifier < ApplicationService
      def initialize(login:, host:, output_dir: nil, stages: Profiles::GeneratePipelineService::STAGES, run_pipeline: true)
        @login = login.to_s.downcase
        @host = host
        @stages = stages
        @run_pipeline = run_pipeline
        @output_dir = Pathname.new(output_dir.presence || default_output_dir)
      end

      def call
        FileUtils.mkdir_p(output_dir)
        context = Context.new(login: login, host: host)

        write_json(output_dir.join("00_initial_context.json"), context.serializable_snapshot)

        stage_results = []
        stages.each_with_index do |stage, idx|
          stage_dir = output_dir.join(format("%02d-%s", idx + 1, stage.id))
          FileUtils.mkdir_p(stage_dir)

          write_json(stage_dir.join("before.json"), context.serializable_snapshot)

          result = stage.service.call(context: context, **stage.options)
          stage_payload = stage_result_payload(stage, result)
          write_json(stage_dir.join("result.json"), stage_payload)
          write_json(stage_dir.join("after.json"), context.serializable_snapshot)
          copy_captures(context.captures, stage_dir.join("captures"))

          stage_results << stage_payload
          if result.failure?
            write_json(output_dir.join("trace.json"), context.trace_entries)
            return failure(result.error || StandardError.new("stage_failed"), metadata: failure_metadata(stage, context, result))
          end
        end

        write_json(output_dir.join("trace.json"), context.trace_entries)
        write_json(output_dir.join("final_context.json"), context.serializable_snapshot)
        copy_captures(context.captures, output_dir.join("captures"))

        pipeline_outcome = nil
        if run_pipeline?
          pipeline_outcome = Profiles::GeneratePipelineService.call(login: login, host: host)
          write_json(output_dir.join("pipeline_result.json"), serialize_service_result(pipeline_outcome))
        end

        success(
          {
            output_dir: output_dir.to_s,
            stages: stage_results,
            pipeline: pipeline_outcome ? serialize_service_result(pipeline_outcome) : nil
          },
          metadata: { output_dir: output_dir.to_s }
        )
      end

      private

      attr_reader :login, :host, :stages, :output_dir, :run_pipeline

      def run_pipeline?
        !!run_pipeline
      end

      def stage_result_payload(stage, result)
        serialize_service_result(
          result,
          extra: {
            stage: stage.id,
            label: stage.label
          }
        )
      end

      def failure_metadata(stage, context, result)
        {
          stage: stage.id,
          label: stage.label,
          output_dir: output_dir.to_s,
          trace: context.trace_entries,
          upstream: safe_json(result.metadata)
        }
      end

      def serialize_service_result(result, extra: {})
        payload = {
          status: result.success? ? "success" : "failure",
          metadata: safe_json(result.metadata),
          error: result.error&.message,
          value: safe_json(result.value)
        }.merge(extra)
        payload
      end

      def copy_captures(captures, target_dir)
        return if captures.blank?

        FileUtils.mkdir_p(target_dir)
        captures.each do |variant, data|
          path = data[:local_path]
          next unless path && File.exist?(path)

          ext = File.extname(path)
          destination = File.join(target_dir, "#{variant}#{ext}")
          FileUtils.cp(path, destination)
        rescue StandardError
          # Ignore copy failures; the JSON snapshot still references source paths.
        end
      end

      def write_json(path, payload)
        json = JSON.pretty_generate(safe_json(payload))
        File.write(path, json)
      end

      def safe_json(object)
        JSON.parse(JSON.generate(object))
      rescue StandardError
        object
      end

      def default_output_dir
        timestamp = Time.current.utc.strftime("%Y%m%d%H%M%S")
        Rails.root.join("tmp", "pipeline_verification", "#{login}-#{timestamp}")
      end
    end
  end
end
