module FeatureFlags
  TRUTHY = %w[1 true yes].freeze
  FALSY  = %w[0 false no].freeze

  def self.enabled?(key)
    env_name = case key.to_sym
    when :submission_manual_inputs then "SUBMISSION_MANUAL_INPUTS_ENABLED"
    when :require_profile_eligibility then "REQUIRE_PROFILE_ELIGIBILITY"
    else key.to_s.upcase
    end

    val = ENV[env_name].to_s.downcase

    if key.to_sym == :require_profile_eligibility
      # Default ON unless explicitly disabled (for paid/Stripe scenarios)
      return !FALSY.include?(val)
    end

    TRUTHY.include?(val)
  end
end
