class GeminiController < ApplicationController
  def up
    result = Gemini::HealthcheckService.call
    if result.success?
      render json: { ok: true, model: Gemini::Configuration.model }, status: :ok
    else
      render json: { ok: false, error: result.error&.message, meta: result.metadata }, status: :service_unavailable
    end
  end
end
