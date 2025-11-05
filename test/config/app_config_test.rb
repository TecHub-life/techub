require "test_helper"

class AppConfigTest < ActiveSupport::TestCase
  AFFECTED_ENV = %w[AXIOM_TOKEN AXIOM_DATASET AXIOM_ENABLED AXIOM_DISABLE].freeze

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

  test "axiom forwarding reports missing token" do
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

  test "axiom forwarding can be forced" do
    Rails.application.credentials.stub(:dig, nil) do
      ENV["AXIOM_TOKEN"] = "secret"
      ENV["AXIOM_DATASET"] = "techub"
      ENV["AXIOM_DISABLE"] = nil
      AppConfig.reload!

      result = AppConfig.axiom_forwarding(force: true)

      assert result[:allowed]
      assert_equal :forced, result[:reason]
    end
  end
end
