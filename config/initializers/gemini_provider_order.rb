# Centralize provider ordering used by rake tasks and services
module Gemini
  # AI Studio only — disable automatic Vertex fallback unless explicitly reconfigured
  PROVIDER_ORDER = %w[ai_studio].freeze unless const_defined?(:PROVIDER_ORDER)
end
