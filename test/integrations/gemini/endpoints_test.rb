require "test_helper"

module Gemini
  class EndpointsTest < ActiveSupport::TestCase
    test "text endpoint for ai_studio" do
      path = Gemini::Endpoints.text_generate_path(provider: "ai_studio", model: "gemini-pro", project_id: "p", location: "l")
      assert_equal "/v1beta/models/gemini-pro:generateContent", path
    end

    test "text endpoint for vertex" do
      path = Gemini::Endpoints.text_generate_path(provider: "vertex", model: "gemini-pro", project_id: "proj", location: "europe-west1")
      assert_equal "/v1/projects/proj/locations/europe-west1/publishers/google/models/gemini-pro:generateContent", path
    end

    test "image endpoint for ai_studio" do
      path = Gemini::Endpoints.image_generate_path(provider: "ai_studio", image_model: "flash-image", project_id: "p", location: "l")
      assert_equal "/v1beta/models/flash-image:generateContent", path
    end

    test "image endpoint for vertex" do
      path = Gemini::Endpoints.image_generate_path(provider: "vertex", image_model: "flash-image", project_id: "proj", location: "us-central1")
      assert_equal "/v1/projects/proj/locations/us-central1/publishers/google/models/flash-image:generateContent", path
    end
  end
end
