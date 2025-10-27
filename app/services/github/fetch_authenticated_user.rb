module Github
  class FetchAuthenticatedUser < ApplicationService
    def initialize(access_token:)
      @access_token = access_token
    end

    def call
      client = Octokit::Client.new(access_token: access_token)
      user = client.user
      emails = []

      success({ user: user, emails: emails })
    rescue Octokit::Error => e
      failure(e)
    end

    private

    attr_reader :access_token
  end
end
