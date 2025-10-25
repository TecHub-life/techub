module Access
  class InviteCodes
    # Reads sign up codes from encrypted credentials under app: sign_up_codes:
    def self.codes
      # Prefer Ops override if present (AppSetting JSON array)
      override = begin
        AppSetting.get_json(:sign_up_codes_override, default: nil)
      rescue StandardError
        nil
      end
      list = if override.is_a?(Array) && override.any?
        override
      else
        Rails.application.credentials.dig(:app, :sign_up_codes)
      end
      Array(list).map(&:to_s).map(&:strip).reject(&:blank?).map(&:downcase).uniq
    end

    def self.valid?(code)
      return false if code.to_s.strip.blank?
      codes.include?(code.to_s.strip.downcase)
    end

    # Global cap on successful invite uses (default 50)
    DEFAULT_LIMIT = 50

    # Returns the configured limit (stored in AppSetting :invite_cap_limit), defaulting to 50
    def self.limit
      (AppSetting.get(:invite_cap_limit, default: DEFAULT_LIMIT.to_s).to_i).clamp(0, 1_000_000)
    end

    # Current number of consumed invites (AppSetting :invite_cap_used)
    def self.used_count
      AppSetting.get(:invite_cap_used, default: "0").to_i
    end

    def self.exhausted?
      used_count >= limit
    end

    # Attempt to consume an invite use if:
    # - the provided code is valid, and
    # - the global cap has not yet been reached.
    # Returns:
    #   :ok        when consumption succeeds
    #   :exhausted when the global cap has been reached
    #   :invalid   when the code is blank/unknown
    def self.consume!(code)
      return :invalid unless valid?(code)

      # Use a DB transaction + row lock for atomic increment of the usage counter
      AppSetting.transaction do
        # Optimistically create the counter if it doesn't exist, then lock and re-read
        counter = AppSetting.find_or_create_by!(key: "invite_cap_used") do |rec|
          rec.value = "0"
        end

        # Lock the counter row to prevent races across concurrent sign-ins
        counter = AppSetting.lock("FOR UPDATE").find_by!(key: "invite_cap_used")

        current = counter.value.to_i
        cap = limit
        return :exhausted if current >= cap

        counter.value = (current + 1).to_s
        counter.save!
        :ok
      end
    rescue StandardError
      # Be conservative: if something goes wrong, do not grant access
      :invalid
    end
  end
end
