module FeatureFlags
  TRUTHY = %w[1 true yes].freeze
  FALSY  = %w[0 false no].freeze

  def self.enabled?(key)
    k = key.to_sym

    # Prefer durable, runtime‑managed app settings (Ops UI) for cost/feature gates
    if defined?(AppSetting)
      case k
      when :ai_images
        return AppSetting.get_bool(:ai_images, default: false)
      when :ai_image_descriptions
        return AppSetting.get_bool(:ai_image_descriptions, default: false)
      when :ai_text
        # Text/traits generation (structured output) — default ON
        return AppSetting.get_bool(:ai_text, default: true)
      when :ai_structured_output
        # Structured JSON formatting — default ON
        return AppSetting.get_bool(:ai_structured_output, default: true)
      end
    end

    env_name = case k
    when :require_profile_eligibility then "REQUIRE_PROFILE_ELIGIBILITY"
    else k.to_s.upcase
    end

    val = ENV[env_name].to_s.downcase

    if k == :require_profile_eligibility
      # Default ON unless explicitly disabled (for paid/Stripe scenarios)
      return !FALSY.include?(val)
    end

    TRUTHY.include?(val)
  end
end
