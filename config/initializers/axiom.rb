# Load Axiom credentials from Rails encrypted credentials into ENV for downstream usage
token = Rails.application.credentials.dig(:axiom, :token)
dataset = Rails.application.credentials.dig(:axiom, :dataset)
metrics_dataset = Rails.application.credentials.dig(:axiom, :metrics_dataset)
ENV["AXIOM_TOKEN"] ||= token if token.present?
ENV["AXIOM_DATASET"] ||= dataset if dataset.present?
ENV["AXIOM_METRICS_DATASET"] ||= metrics_dataset if metrics_dataset.present?

# Optionally set OTEL endpoint from credentials
otel_endpoint = Rails.application.credentials.dig(:otel, :endpoint)
ENV["OTEL_EXPORTER_OTLP_ENDPOINT"] ||= otel_endpoint if otel_endpoint.present?
