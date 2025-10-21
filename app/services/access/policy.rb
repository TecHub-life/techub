module Access
  class Policy
    DEFAULT_ALLOWED = %w[loftwah jrh89].freeze

    def self.open_access?
      AppSetting.get_bool(:open_access, default: false)
    end

    def self.allowed_logins
      AppSetting.get_json(:allowed_logins, default: DEFAULT_ALLOWED)
    end

    def self.allowed?(login)
      return true if open_access?
      return false if login.to_s.strip.empty?
      allowed_logins.map(&:downcase).include?(login.to_s.downcase)
    end

    def self.seed_defaults!
      AppSetting.set_json(:allowed_logins, DEFAULT_ALLOWED) if AppSetting.get(:allowed_logins).nil?
      AppSetting.set_bool(:open_access, false) if AppSetting.get(:open_access).nil?
    end
  end
end
