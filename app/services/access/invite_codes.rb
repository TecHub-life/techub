module Access
  class InviteCodes
    # Reads sign up codes from encrypted credentials under app: sign_up_codes:
    def self.codes
      list = Rails.application.credentials.dig(:app, :sign_up_codes)
      Array(list).map(&:to_s).map(&:strip).reject(&:blank?).map(&:downcase).uniq
    end

    def self.valid?(code)
      return false if code.to_s.strip.blank?
      codes.include?(code.to_s.strip.downcase)
    end
  end
end
