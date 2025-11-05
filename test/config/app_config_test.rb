require "test_helper"

class AppConfigTest < ActiveSupport::TestCase
  AFFECTED_ENV = %w[AXIOM_TOKEN AXIOM_DATASET AXIOM_ENABLED APP_ENV].freeze

  setup do
    @env_backup = AFFECTED_ENV.to_h { |key| [ key, ENV[key] ] }
  end

  teardown do
    AFFECTED_ENV.each do |key|
      value = @env_backup[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    AppConfig.reload!
  end

  test "forwarding disabled by default outside production" do
    Rails.application.credentials.stub(:dig, nil) do
      ENV["AXIOM_TOKEN"] = "secret"
      ENV["AXIOM_DATASET"] = "techub"
      ENV.delete("APP_ENV")
      ENV.delete("AXIOM_ENABLED")
      AppConfig.reload!

      result = AppConfig.axiom_forwarding

      assert_equal :disabled, result[:reason]
      refute result[:allowed]
    end
  end

  test "forwarding enabled when flag set" do
    Rails.application.credentials.stub(:dig, nil) do
      ENV["AXIOM_TOKEN"] = "secret"
      ENV["AXIOM_DATASET"] = "techub"
      ENV["AXIOM_ENABLED"] = "1"
      AppConfig.reload!

      result = AppConfig.axiom_forwarding

      assert result[:allowed]
      assert_equal :flag_enabled, result[:reason]
    end
  end

  test "forwarding enabled by default in production" do
    Rails.application.credentials.stub(:dig, nil) do
      ENV["AXIOM_TOKEN"] = "secret"
      ENV["AXIOM_DATASET"] = "techub"
      ENV["APP_ENV"] = "production"
      ENV.delete("AXIOM_ENABLED")
      AppConfig.reload!

      result = AppConfig.axiom_forwarding

      assert result[:allowed]
      assert_equal :production_default, result[:reason]
    end
  end

  test "forwarding can be forced even when disabled" do
    Rails.application.credentials.stub(:dig, nil) do
      ENV["AXIOM_TOKEN"] = "secret"
      ENV["AXIOM_DATASET"] = "techub"
      ENV.delete("AXIOM_ENABLED")
      AppConfig.reload!

      result = AppConfig.axiom_forwarding(force: true)

      assert result[:allowed]
      assert_equal :forced, result[:reason]
    end
  end

  test "missing token blocks forwarding even when enabled" do
    Rails.application.credentials.stub(:dig, nil) do
      ENV["AXIOM_TOKEN"] = nil
      ENV["AXIOM_DATASET"] = "techub"
      ENV["AXIOM_ENABLED"] = "1"
      AppConfig.reload!

      result = AppConfig.axiom_forwarding

      assert_equal :missing_token, result[:reason]
      refute result[:allowed]
    end
  end
end
