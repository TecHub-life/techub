require "test_helper"

module Gemini
  class ClientServiceTest < ActiveSupport::TestCase
    CredentialsStub = Struct.new(:payload) do
      def dig(*keys)
        payload.dig(*keys)
      end
    end

    test "builds Faraday client with bearer token" do
      creds = { google: { project_id: "proj", location: "us-central1", application_credentials_json: { "type" => "service_account" }.to_json } }
      Rails.application.stub :credentials, CredentialsStub.new(creds) do
        fake_auth = Minitest::Mock.new
        def fake_auth.fetch_access_token!; { "access_token"=>"t" }; end
        def fake_auth.access_token; "t"; end

        Google::Auth::ServiceAccountCredentials.stub :make_creds, fake_auth do
          result = Gemini::ClientService.call
          assert result.success?
          conn = result.value
          assert_equal "Bearer t", conn.headers["Authorization"]
        end
      end
    end
  end
end
