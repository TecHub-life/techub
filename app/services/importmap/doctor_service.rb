# frozen_string_literal: true

require "pathname"

module Importmap
  class DoctorService < ApplicationService
    StepResult = Struct.new(:id, :label, :status, :message, :metadata, keyword_init: true)

    STEPS = [
      {
        id: :load_importmap,
        label: "Load config/importmap.rb",
        description: "Ensure importmap file exists and gather pin metadata"
      },
      {
        id: :load_application_entrypoint,
        label: "Load app/javascript/application.js",
        description: "Collect import statements we must satisfy"
      },
      {
        id: :validate_application_imports,
        label: "Validate application imports",
        description: "Confirm every import from application.js is pinned"
      },
      {
        id: :validate_controllers_access,
        label: "Validate Stimulus controllers access",
        description: "Ensure controllers directory is accessible via pin_all_from"
      },
      {
        id: :validate_critical_dependencies,
        label: "Validate critical dependencies",
        description: "Confirm Turbo/Stimulus packages are pinned"
      },
      {
        id: :validate_custom_modules,
        label: "Validate custom modules",
        description: "Ensure bespoke modules (eg techub_console) are pinned and present"
      }
    ].freeze

    DEFAULT_CRITICAL_DEPENDENCIES = [
      "@hotwired/turbo-rails",
      "@hotwired/stimulus",
      "@hotwired/stimulus-loading"
    ].freeze
    DEFAULT_CUSTOM_MODULES = %w[techub_console].freeze

    def self.steps
      STEPS.map { |step| step[:id] }
    end

    def self.describe
      STEPS.map(&:dup)
    end

    def initialize(
      importmap_path: Pathname.new("config/importmap.rb"),
      application_js_path: Pathname.new("app/javascript/application.js"),
      controllers_dir: Pathname.new("app/javascript/controllers"),
      critical_dependencies: DEFAULT_CRITICAL_DEPENDENCIES,
      custom_modules: DEFAULT_CUSTOM_MODULES
    )
      @importmap_path = Pathname.new(importmap_path)
      @application_js_path = Pathname.new(application_js_path)
      @controllers_dir = Pathname.new(controllers_dir)
      @critical_dependencies = Array(critical_dependencies)
      @custom_modules = normalize_modules(custom_modules)
    end

    def call
      steps = []
      pins = {}
      pin_all_from_patterns = []
      application_imports = []

      perform_step(:load_importmap, steps) do
        ensure_file!(@importmap_path, "config/importmap.rb")
        content = @importmap_path.read
        pins = extract_pins(content)
        pin_all_from_patterns = extract_pin_all_from(content)
        {
          message: "Found #{pins.size} pins and #{pin_all_from_patterns.size} pin_all_from directives",
          metadata: { pins: pins.keys.sort, pin_all_from: pin_all_from_patterns }
        }.merge(value: content)
      end
      return failure(StandardError.new("importmap_missing"), metadata: { steps: steps }) if failed?(steps)

      perform_step(:load_application_entrypoint, steps) do
        ensure_file!(@application_js_path, "app/javascript/application.js")
        content = @application_js_path.read
        application_imports = extract_application_imports(content)
        {
          message: "Detected #{application_imports.size} imports in application.js",
          metadata: { imports: application_imports }
        }.merge(value: content)
      end
      return failure(StandardError.new("application_js_missing"), metadata: { steps: steps }) if failed?(steps)

      perform_step(:validate_application_imports, steps) do
        missing = find_missing_imports(application_imports, pins, pin_all_from_patterns)
        if missing.empty?
          { message: "All imports present", metadata: { imports: application_imports } }
        else
          { status: :failed, message: "Missing pins for #{missing.join(', ')}", metadata: { missing: missing } }
        end
      end

      perform_step(:validate_controllers_access, steps) do
        unless @controllers_dir.exist?
          { status: :degraded, message: "Controllers directory #{@controllers_dir} not found", metadata: {} }
        else
          controller_files = @controllers_dir.glob("**/*_controller.js")
          has_pin = pin_all_from_patterns.any? do |pattern|
            pattern[:dir] == @controllers_dir.to_s && pattern[:under] == "controllers"
          end
          if has_pin
            { message: "Controllers accessible (#{controller_files.size} files)", metadata: { controller_count: controller_files.size } }
          else
            { status: :failed, message: 'Missing pin_all_from "app/javascript/controllers", under: "controllers"', metadata: {} }
          end
        end
      end

      perform_step(:validate_critical_dependencies, steps) do
        missing = @critical_dependencies.reject { |dep| pins.key?(dep) }
        if missing.empty?
          { message: "All critical dependencies pinned", metadata: { dependencies: @critical_dependencies } }
        else
          { status: :failed, message: "Missing critical dependencies: #{missing.join(', ')}", metadata: { missing: missing } }
        end
      end

      perform_step(:validate_custom_modules, steps) do
        missing = []
        missing_files = []
        @custom_modules.each do |mod|
          missing << mod[:name] unless pins.key?(mod[:name])
          missing_files << mod[:path].to_s unless mod[:path].exist?
        end
        if missing.empty? && missing_files.empty?
          { message: "Custom modules present", metadata: { modules: @custom_modules.map { |mod| mod[:name] } } }
        else
          {
            status: :failed,
            message: "Custom module issues detected",
            metadata: { missing_pins: missing, missing_files: missing_files }
          }
        end
      end

      metadata = {
        steps: steps.map(&:to_h),
        pins: pins.keys.sort,
        imports: application_imports,
        controllers_dir: @controllers_dir.to_s
      }

      if steps.any? { |step| step.status == :failed }
        failure(StandardError.new("importmap_integrity_failed"), metadata: metadata)
      elsif steps.any? { |step| step.status == :degraded }
        degraded(metadata, metadata: metadata)
      else
        success(metadata, metadata: metadata)
      end
    end

    private

    def perform_step(id, steps)
      result = yield
      status = result[:status] || :ok
      steps << StepResult.new(
        id: id,
        label: label_for(id),
        status: status,
        message: result[:message],
        metadata: result[:metadata]
      )
      result[:value]
    rescue StandardError => e
      steps << StepResult.new(
        id: id,
        label: label_for(id),
        status: :failed,
        message: e.message,
        metadata: {}
      )
      nil
    end

    def failed?(steps)
      steps.any? { |step| step.status == :failed }
    end

    def label_for(id)
      (STEPS.find { |step| step[:id] == id } || {})[:label] || id.to_s.humanize
    end

    def ensure_file!(path, human_label)
      return if path.exist?

      raise StandardError, "#{human_label} not found at #{path}"
    end

    def extract_pins(content)
      pins = {}
      content.scan(/^pin\s+"([^"]+)"/) { |match| pins[match[0]] = true }
      pins
    end

    def extract_pin_all_from(content)
      patterns = []
      content.scan(/^pin_all_from\s+"([^"]+)"(?:,\s*under:\s+"([^"]+)")?/) do |match|
        patterns << { dir: match[0], under: match[1] || "" }
      end
      patterns
    end

    def extract_application_imports(content)
      content.scan(/^import\s+(?:'([^']+)'|"([^"]+)")/).flatten.compact
    end

    def find_missing_imports(imports, pins, pin_all_from_patterns)
      imports.reject do |import_name|
        pins.key?(import_name) || pin_all_from_patterns.any? { |pattern| pattern[:under] == import_name }
      end
    end

    def normalize_modules(modules)
      Array(modules).map do |mod|
        if mod.is_a?(Hash)
          {
            name: mod[:name].to_s,
            path: Pathname.new(mod[:path] || "app/javascript/#{mod[:name]}.js")
          }
        else
          mod_name = mod.to_s
          { name: mod_name, path: Pathname.new("app/javascript/#{mod_name}.js") }
        end
      end
    end
  end
end
