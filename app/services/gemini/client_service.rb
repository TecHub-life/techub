require "googleauth"
require "faraday"

module Gemini
  class ClientService < ApplicationService
    SCOPE = [ "https://www.googleapis.com/auth/cloud-platform" ].freeze

    def initialize(project_id: Gemini::Configuration.project_id, location: Gemini::Configuration.location)
      @project_id = project_id
      @location = location
    end

    def call
      Gemini::Configuration.validate!

      token_result = obtain_access_token
      return token_result if token_result.failure?

      token = token_result.value
      base_url = "https://#{location}-aiplatform.googleapis.com"

      conn = Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json, content_type: /json/
        f.adapter Faraday.default_adapter
      end

      conn.headers["Authorization"] = "Bearer #{token}"
      conn.headers["x-goog-user-project"] = project_id if project_id
      conn.headers["Accept"] = "application/json"
      success(conn, metadata: { project_id: project_id, location: location })
    rescue StandardError => e
      failure(e)
    end

    private

    attr_reader :project_id, :location

    def obtain_access_token
      creds_json = Gemini::Configuration.application_credentials_json
      creds_path = nil

      authorizer = if creds_json.present?
        Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: StringIO.new(creds_json), scope: SCOPE)
      else
        creds_path = Gemini::Configuration.application_credentials_path
        if creds_path.present?
          Google::Auth::ServiceAccountCredentials.make_creds(json_key_io: File.open(creds_path), scope: SCOPE)
        else
          Google::Auth.get_application_default(SCOPE)
        end
      end

      authorizer.fetch_access_token!
      success(authorizer.access_token, metadata: { via: creds_json.present? ? :json : (creds_path.present? ? :path : :adc) })
    rescue StandardError => e
      failure(e)
    end
  end
end
