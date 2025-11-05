require "json"
require "fileutils"

module Profiles
  module Pipeline
    class SnapshotWriter
      attr_reader :result, :output_dir, :copy_files

      def self.call(result:, output_dir:, copy_files: true)
        new(result: result, output_dir: output_dir, copy_files: copy_files).call
      end

      def initialize(result:, output_dir:, copy_files: true)
        @result = result
        @output_dir = Pathname.new(output_dir)
        @copy_files = copy_files
      end

      def call
        return unless result.respond_to?(:metadata)

        FileUtils.mkdir_p(output_dir)
        write_json("metadata.json", metadata)
        write_json("pipeline_snapshot.json", pipeline_snapshot)
        write_json("trace.json", metadata[:trace]) if metadata[:trace].present?
        write_json("stage_metadata.json", stage_metadata) if stage_metadata.present?

        snapshot = pipeline_snapshot
        write_json("github_payload.json", snapshot[:github_payload]) if snapshot[:github_payload].present?
        write_json("profile.json", snapshot[:profile]) if snapshot[:profile].present?
        write_json("card.json", snapshot[:card]) if snapshot[:card].present?
        write_json("eligibility.json", snapshot[:eligibility]) if snapshot[:eligibility].present?
        write_json("screenshots.json", snapshot[:captures]) if snapshot[:captures].present?
        write_json("optimizations.json", snapshot[:optimizations]) if snapshot[:optimizations].present?

        ai_metadata = stage_metadata&.dig(:generate_ai_profile) || {}
        write_json("ai_metadata.json", ai_metadata) if ai_metadata.present?
        if ai_metadata[:metadata].is_a?(Hash) && ai_metadata[:metadata][:prompt].present?
          write_json("ai_prompt.json", ai_metadata[:metadata][:prompt])
        end
        response_preview = ai_metadata.dig(:metadata, :response_preview)
        write_text("ai_response_preview.txt", response_preview) if response_preview.present?

        copy_captures(snapshot[:captures])
        output_dir
      end

      private

      def metadata
        @metadata ||= begin
          data = result.metadata || {}
          symbolize_keys(data)
        end
      end

      def stage_metadata
        metadata[:stage_metadata]
      end

      def pipeline_snapshot
        metadata[:pipeline_snapshot] || {}
      end

      def write_json(filename, payload)
        return if payload.nil?

        serialized = payload.respond_to?(:as_json) ? payload.as_json : payload
        path = output_dir.join(filename)
        File.write(path, JSON.pretty_generate(serialized))
      rescue StandardError
        # noop; avoid snapshot failure
      end

      def write_text(filename, text)
        path = output_dir.join(filename)
        File.write(path, text.to_s)
      rescue StandardError
        # noop
      end

      def copy_captures(captures)
        return unless copy_files
        return unless captures.is_a?(Hash)

        dest = output_dir.join("captures")
        FileUtils.mkdir_p(dest)
        captures.each do |variant, data|
          local_path = data[:local_path] || data["local_path"]
          next unless local_path && File.exist?(local_path)

          ext = File.extname(local_path)
          target = dest.join("#{variant}#{ext}")
          FileUtils.cp(local_path, target)
        rescue StandardError
          # continue copying other captures
        end
      end

      def symbolize_keys(value)
        case value
        when Hash
          value.each_with_object({}) do |(k, v), memo|
            memo[k.to_sym] = symbolize_keys(v)
          end
        when Array
          value.map { |item| symbolize_keys(item) }
        else
          value
        end
      end
    end
  end
end
