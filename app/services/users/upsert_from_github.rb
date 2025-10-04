module Users
  class UpsertFromGithub < ApplicationService
    def initialize(user_payload:, access_token:)
      @user_payload = user_payload
      @access_token = access_token
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

      if user.save
        success(user)
      else
        failure(StandardError.new(user.errors.full_messages.to_sentence))
      end
    end

    private

    attr_reader :user_payload, :access_token
  end
end
