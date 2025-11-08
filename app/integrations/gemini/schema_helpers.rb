module Gemini
  module SchemaHelpers
    module_function

    def to_ai_studio_type_schema(schema)
      return {} unless schema.is_a?(Hash)

      transform = lambda do |node|
        return node unless node.is_a?(Hash)

        out = {}
        node.each do |k, v|
          key = k.to_s
          case key
          when "type"
            out[key] = map_type_to_ai_studio(v)
          when "properties"
            props = {}
            v.to_h.each { |pk, pv| props[pk.to_s] = transform.call(pv) }
            out[key] = props
          when "items"
            out[key] = transform.call(v)
          else
            out[key] = v.is_a?(Hash) ? transform.call(v) : v
          end
        end
        out
      end

      transform.call(schema)
    end

    def map_type_to_ai_studio(value)
      t = value.to_s.downcase
      case t
      when "object" then "OBJECT"
      when "string" then "STRING"
      when "integer" then "INTEGER"
      when "number" then "NUMBER"
      when "array" then "ARRAY"
      when "boolean" then "BOOLEAN"
      else value
      end
    end
  end
end
