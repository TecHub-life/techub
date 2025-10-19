# Load Axiom credentials from Rails encrypted credentials into ENV for downstream usage
token = Rails.application.credentials.dig(:axiom, :token)
dataset = Rails.application.credentials.dig(:axiom, :dataset)
ENV["AXIOM_TOKEN"] ||= token if token.present?
ENV["AXIOM_DATASET"] ||= dataset if dataset.present?

# Optionally set OTEL endpoint from credentials
otel_endpoint = Rails.application.credentials.dig(:otel, :endpoint)
ENV["OTEL_EXPORTER_OTLP_ENDPOINT"] ||= otel_endpoint if otel_endpoint.present?
