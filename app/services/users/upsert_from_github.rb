module Users
  class UpsertFromGithub < ApplicationService
    def initialize(user_payload:, access_token:, emails: nil)
      @user_payload = user_payload
      @access_token = access_token
      @emails = emails
    end

    def call
      github_id = user_payload[:id]
      login = user_payload[:login]

      user = User.find_or_initialize_by(github_id: github_id)
      user.assign_attributes(
        login: login,
        name: user_payload[:name],
        avatar_url: user_payload[:avatar_url]
      )
      user.access_token = access_token

      # Capture email if provided (primary verified preferred)
      if emails.present?
        chosen = pick_best_email(Array(emails))
        user.email = normalize_email(chosen) if chosen.present?
      end

      if user.save
        success(user)
      else
        failure(StandardError.new(user.errors.full_messages.to_sentence))
      end
    end

    private

    attr_reader :user_payload, :access_token, :emails

    def pick_best_email(list)
      # Octokit returns an array of hashes with keys: :email, :primary, :verified
      primary_verified = list.find { |e| truthy?(e[:primary]) && truthy?(e[:verified]) }&.dig(:email)
      return primary_verified if primary_verified.present?

      primary = list.find { |e| truthy?(e[:primary]) }&.dig(:email)
      return primary if primary.present?

      list.first&.dig(:email)
    end

    def normalize_email(email)
      email.to_s.strip.downcase.presence
    end

    def truthy?(v)
      v == true || v.to_s == "true"
    end
  end
end
