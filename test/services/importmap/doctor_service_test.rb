# frozen_string_literal: true

require "test_helper"
require "tmpdir"

module Importmap
  class DoctorServiceTest < ActiveSupport::TestCase
    def test_success_with_valid_inputs
      with_temp_structure do |paths|
        result = Importmap::DoctorService.new(
          importmap_path: paths[:importmap],
          application_js_path: paths[:application_js],
          controllers_dir: paths[:controllers_dir],
          custom_modules: [ { name: "techub_console", path: paths[:custom_module] } ],
          critical_dependencies: [ "@hotwired/turbo-rails", "@hotwired/stimulus", "@hotwired/stimulus-loading" ]
        ).call

        assert result.success?, "Expected doctor to succeed, got #{result.status}"
        assert_equal :ok, result.status
        assert_equal 0, Array(result.metadata[:steps]).count { |step| step[:status] == :failed }
      end
    end

    def test_failure_when_import_missing
      with_temp_structure(modify_imports: [ "missing_module" ]) do |paths|
        result = Importmap::DoctorService.new(
          importmap_path: paths[:importmap],
          application_js_path: paths[:application_js],
          controllers_dir: paths[:controllers_dir],
          custom_modules: [ { name: "techub_console", path: paths[:custom_module] } ],
          critical_dependencies: [ "@hotwired/turbo-rails", "@hotwired/stimulus", "@hotwired/stimulus-loading" ]
        ).call

        refute result.success?
        assert result.failure?
        failing_step = result.metadata[:steps].find { |step| step[:id] == :validate_application_imports }
        assert_equal :failed, failing_step[:status]
      end
    end

    private

    def with_temp_structure(modify_imports: nil)
      Dir.mktmpdir do |dir|
        base = Pathname.new(dir)
        importmap = base.join("importmap.rb")
        application_js = base.join("application.js")
        controllers_dir = base.join("controllers")
        custom_module = base.join("techub_console.js")

        controllers_dir.mkpath
        controllers_dir.join("tabs_controller.js").write("export default class {}")
        custom_module.write("export const TecHubConsole = {}")

        importmap.write(<<~RUBY)
          pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
          pin "@hotwired/stimulus", to: "stimulus.js", preload: true
          pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
          pin "controllers", to: "controllers.js"
          pin "techub_console", to: "techub_console.js"
          pin_all_from "#{controllers_dir}", under: "controllers"
        RUBY

        imports = [
          "@hotwired/turbo-rails",
          "controllers",
          "techub_console"
        ]
        imports = modify_imports if modify_imports
        application_js.write(imports.map { |imp| %(import "#{imp}") }.join("\n"))

        yield({
          importmap: importmap,
          application_js: application_js,
          controllers_dir: controllers_dir,
          custom_module: custom_module
        })
      end
    end
  end
end
