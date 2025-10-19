namespace :credentials do
  # ---- Helpers ----
  # Build a conservative schema of expected credentials used across the app.
  def expected_credentials_schema
    {
      "secret_key_base" => "",
      "app" => { "host" => "" },
      "github" => {
        "app_id" => "",
        "client_id" => "",
        "client_secret" => "",
        "installation_id" => "",
        "private_key" => "",
        "webhook_secret" => ""
      },
      "resend" => { "api_key" => "" },
      "active_record_encryption" => {
        "primary_key" => "",
        "deterministic_key" => "",
        "key_derivation_salt" => ""
      },
      "do_spaces" => {
        "endpoint" => "",
        "cdn_endpoint" => "",
        "bucket_name" => "",
        "region" => "",
        "access_key_id" => "",
        "secret_access_key" => ""
      },
      # Top-level Gemini config (preferred when present)
      "gemini" => {
        "provider" => "",
        "project_id" => "",
        "location" => "",
        "api_key" => "",
        "api_base" => "",
        "image_model" => ""
      },
      # Google-scoped fallbacks supported by Gemini::Configuration
      "google" => {
        "project_id" => "",
        "location" => "",
        "api_key" => "",
        "ai_studio" => {
          "api_key" => "",
          "api_base" => ""
        },
        "gemini" => {
          "provider" => "",
          "project_id" => "",
          "location" => "",
          "api_key" => "",
          "api_base" => "",
          "image_model" => ""
        },
        "application_credentials_path" => "",
        "application_credentials_json" => ""
      },
      "mission_control" => {
        "jobs" => {
          "http_basic" => "",
          "alert_email" => ""
        }
      },
      "axiom" => { "token" => "", "dataset" => "" },
      "otel" => { "endpoint" => "" }
    }
  end

  def deep_convert_to_hash(object)
    case object
    when Hash
      object.each_with_object({}) { |(k, v), h| h[k] = deep_convert_to_hash(v) }
    when Array
      object.map { |v| deep_convert_to_hash(v) }
    else
      if object.respond_to?(:to_h)
        deep_convert_to_hash(object.to_h)
      else
        object
      end
    end
  end

  def deep_merge_hash(a, b)
    return b unless a.is_a?(Hash) && b.is_a?(Hash)
    a.merge(b) { |_k, av, bv| deep_merge_hash(av, bv) }
  end

  def flatten_hash_to_env_keys(object, prefix = [])
    case object
    when Hash
      object.each_with_object({}) do |(key, value), flattened|
        next if key.nil?
        next_prefix = prefix + [ key.to_s ]
        flattened.merge!(flatten_hash_to_env_keys(value, next_prefix))
      end
    when Array
      object.each_with_index.each_with_object({}) do |(value, index), flattened|
        next_prefix = prefix + [ index.to_s ]
        flattened.merge!(flatten_hash_to_env_keys(value, next_prefix))
      end
    else
      env_key = prefix.map { |k| k.gsub(/[^a-zA-Z0-9]+/, "_").upcase }.join("_")
      { env_key => object }
    end
  end

  def mask_values(obj)
    case obj
    when Hash
      obj.each_with_object({}) do |(k, v), h|
        h[k.to_s] = mask_values(v)
      end
    when Array
      obj.map { |v| mask_values(v) }
    else
      ""
    end
  end

  # ---- Tasks ----
  desc "Generate config/credentials.example.yml (masked, schema‑aware)"
  task :example => :environment do
    root = Rails.application.credentials.respond_to?(:config) ? Rails.application.credentials.config : Rails.application.credentials
    creds = deep_convert_to_hash(root)
    schema = expected_credentials_schema
    merged = deep_merge_hash(schema, creds)
    masked = mask_values(merged)
    path = Rails.root.join("config", "credentials.example.yml")
    File.write(path, masked.to_yaml)
    puts "Wrote #{path}"
  end

  desc "Generate .env.from_credentials.example (flattened, values blank)"
  task :env => :environment do
    root = Rails.application.credentials.respond_to?(:config) ? Rails.application.credentials.config : Rails.application.credentials
    creds = deep_convert_to_hash(root)
    flattened = flatten_hash_to_env_keys(creds)
    lines = []
    lines << "# Generated from Rails credentials; values intentionally left blank"
    lines << "# Edit and copy to .env to use locally"
    flattened.keys.sort.each do |key|
      next if key == "ENV"
      lines << "#{key}="
    end
    path = Rails.root.join(".env.from_credentials.example")
    File.write(path, lines.join("\n") + "\n")
    puts "Wrote #{path}"
  end

  # ---- Backwards‑compat aliases ----
  desc "(alias) Export masked credentials to config/credentials.example.yml"
  task :export_example_yaml => :environment do
    Rake::Task["credentials:example"].invoke
  end

  desc "(alias) Export flattened .env.from_credentials.example from credentials"
  task :export_env_example => :environment do
    Rake::Task["credentials:env"].invoke
  end
end

