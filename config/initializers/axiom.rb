# Load the Axiom ingest token from Rails credentials into ENV for downstream usage.
token = Rails.application.credentials.dig(:axiom, :token)
ENV["AXIOM_TOKEN"] ||= token if token.present?
