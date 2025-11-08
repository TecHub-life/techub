module Gemini
  module Providers
    class Adapter
      def self.for(provider)
        case provider.to_s
        when "ai_studio"
          Gemini::Providers::AiStudioAdapter.new
        else
          Gemini::Providers::VertexAdapter.new
        end
      end

      # Interface methods — concrete adapters must implement
      def system_instruction_hash(_text)
        raise NotImplementedError
      end

      def contents_for_text(text)
        [ { role: "user", parts: [ { text: text } ] } ]
      end

      def contents_for_text_with_image(text, mime_type, data)
        [
          {
            role: "user",
            parts: [
              { text: text },
              { inline_data: { mime_type: mime_type, data: data } }
            ]
          }
        ]
      end

      def generation_config_hash(_temperature:, _max_tokens:, _schema: nil, _structured_json: false)
        raise NotImplementedError
      end

      def envelope(contents:, generation_config:, system_instruction: nil)
        raise NotImplementedError
      end
    end

    # Eager-load concrete adapters after base class is defined to avoid inheritance order issues
    begin
      require_dependency "gemini/providers/ai_studio_adapter"
      require_dependency "gemini/providers/vertex_adapter"
    rescue NameError
      # In some test autoload orders, dependency may already be loaded; ignore
    end
  end
end
