require "test_helper"

class GeminiControllerTest < ActionDispatch::IntegrationTest
  test "up ok" do
    Gemini::HealthcheckService.stub :call, ServiceResult.success({ status: "ok" }) do
      get "/up/gemini"
      assert_response :success
      assert_equal({ "ok"=>true, "model"=>"gemini-2.5-flash" }, JSON.parse(response.body))
    end
  end

  test "up failure" do
    err = StandardError.new("boom")
    Gemini::HealthcheckService.stub :call, ServiceResult.failure(err, metadata: { http_status: 500 }) do
      get "/up/gemini"
      assert_response :service_unavailable
      body = JSON.parse(response.body)
      assert_equal false, body["ok"]
      assert_equal "boom", body["error"]
    end
  end

  test "image ok" do
    Gemini::ImageGenerationHealthcheckService.stub :call, ServiceResult.success({ status: "ok", model: "google/imagegeneration" }) do
      get "/up/gemini/image"
      assert_response :success
      assert_equal({ "ok"=>true, "model"=>"google/imagegeneration" }, JSON.parse(response.body))
    end
  end

  test "image failure" do
    err = StandardError.new("no imagen")
    Gemini::ImageGenerationHealthcheckService.stub :call, ServiceResult.failure(err, metadata: { http_status: 404 }) do
      get "/up/gemini/image"
      assert_response :service_unavailable
      body = JSON.parse(response.body)
      assert_equal false, body["ok"]
      assert_equal "no imagen", body["error"]
    end
  end
end
