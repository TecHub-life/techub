require "test_helper"

module Gemini
  class ImageGenerationHealthcheckServiceTest < ActiveSupport::TestCase
    CredentialsStub = Struct.new(:payload) do
      def dig(*keys)
        payload.dig(*keys)
      end
    end

    setup do
      ENV["GEMINI_PROVIDER"] = "vertex"
      ENV["GOOGLE_CLOUD_PROJECT"] = "proj"
      ENV["GEMINI_LOCATION"] = "us-central1"
    end

    test "returns success on 200" do
      Rails.application.stub :credentials, CredentialsStub.new({ google: { project_id: "proj", location: "us-central1" } }) do
        dummy_conn = Faraday.new(url: "https://us-central1-aiplatform.googleapis.com") do |f|
          f.adapter :test, Faraday::Adapter::Test::Stubs.new { |stub|
            stub.post("/v1/projects/proj/locations/us-central1/publishers/google/models/gemini-2.5-flash-image:generateContent") { |env| [ 200, { "content-type"=>"application/json" }, { candidates: [] } ] }
          }
        end

        Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
          result = Gemini::ImageGenerationHealthcheckService.call
          assert result.success?
        end
      end
    end

    test "returns failure on non-2xx" do
      Rails.application.stub :credentials, CredentialsStub.new({ google: { project_id: "proj", location: "us-central1" } }) do
        dummy_conn = Faraday.new(url: "https://us-central1-aiplatform.googleapis.com") do |f|
          f.adapter :test, Faraday::Adapter::Test::Stubs.new { |stub|
            stub.post("/v1/projects/proj/locations/us-central1/publishers/google/models/gemini-2.5-flash-image:generateContent") { |env| [ 403, { "content-type"=>"application/json" }, { error: "forbidden" } ] }
          }
        end

        Gemini::ClientService.stub :call, ServiceResult.success(dummy_conn) do
          result = Gemini::ImageGenerationHealthcheckService.call
          assert result.failure?
        end
      end
    end
  end
end
