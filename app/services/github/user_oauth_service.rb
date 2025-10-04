module Github
  class UserOauthService < ApplicationService
    def initialize(code:, redirect_uri:)
      @code = code
      @redirect_uri = redirect_uri
    end

    def call
      response = Octokit.exchange_code_for_token(
        Github::Configuration.client_id,
        Github::Configuration.client_secret,
        code,
        redirect_uri: redirect_uri
      )

      if response[:error].present?
        return failure(StandardError.new(response[:error_description] || "OAuth exchange failed"))
      end

      success({
        access_token: response[:access_token],
        token_type: response[:token_type],
        scope: response[:scope]
      })
    rescue Octokit::Unauthorized => e
      failure(e)
    end

    private

    attr_reader :code, :redirect_uri
  end
end
