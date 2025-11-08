module Gemini
  module Endpoints
    module_function

    def text_generate_path(provider:, model:, project_id:, location:)
      if provider == "ai_studio"
        "/v1beta/models/#{model}:generateContent"
      else
        "/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{model}:generateContent"
      end
    end

    def image_generate_path(provider:, image_model:, project_id:, location:)
      if provider == "ai_studio"
        "/v1beta/models/#{image_model}:generateContent"
      else
        "/v1/projects/#{project_id}/locations/#{location}/publishers/google/models/#{image_model}:generateContent"
      end
    end
  end
end
