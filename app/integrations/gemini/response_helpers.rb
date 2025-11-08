module Gemini
  module ResponseHelpers
    # Safely dig into a hash-like object using symbol or string keys
    def dig_value(source, key)
      return nil unless source.respond_to?(:[])

      return source[key] if source.key?(key) rescue nil

      string_key = key.to_s
      return source[string_key] if source.key?(string_key) rescue nil

      symbol_key = key.is_a?(String) ? key.to_sym : key
      source[symbol_key]
    end

    # Normalize potential JSON/string body into a Ruby hash
    def normalize_to_hash(body)
      return body if body.is_a?(Hash)

      if body.respond_to?(:to_hash)
        body.to_hash
      elsif body.present?
        JSON.parse(body)
      end
    rescue JSON::ParserError
      nil
    end

    # Lenient JSON parsing with trailing-comma and fenced-code tolerance
    def parse_relaxed_json(text)
      value = text.to_s
      return nil if value.strip.empty?

      begin
        return JSON.parse(value)
      rescue JSON::ParserError
        # try stripped trailing commas in objects/arrays
      end

      begin
        cleaned = value.gsub(/,\s*(?=[}\]])/, "")
        return JSON.parse(cleaned)
      rescue JSON::ParserError
        # try fenced code block
      end

      if value =~ /```(?:json)?\s*([\s\S]*?)\s*```/i
        fenced = $1
        begin
          return JSON.parse(fenced)
        rescue JSON::ParserError
          # ignore and fall through
        end
      end

      # Try to extract the first balanced JSON object from noisy output (e.g., warnings + JSON)
      extracted = extract_first_json_object(value)
      return extracted if extracted

      nil
    end

    # Heuristic: find first balanced { ... } block and parse it as JSON
    def extract_first_json_object(text)
      s = text.to_s
      start_idx = nil
      depth = 0
      s.each_char.with_index do |ch, i|
        if ch == "{"
          start_idx ||= i
          depth += 1
        elsif ch == "}" && start_idx
          depth -= 1
          if depth == 0
            candidate = s[start_idx..i]
            begin
              obj = JSON.parse(candidate)
              return obj if obj.is_a?(Hash)
            rescue JSON::ParserError
              # keep scanning for next block
            ensure
              # reset to look for next object
              start_idx = nil
              depth = 0
            end
          end
        end
      end
      nil
    end
  end
end
