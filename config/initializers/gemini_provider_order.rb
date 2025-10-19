# Centralize provider ordering used by rake tasks and services
module Gemini
  PROVIDER_ORDER = %w[ai_studio vertex].freeze unless const_defined?(:PROVIDER_ORDER)
end
