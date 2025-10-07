namespace :credentials do
  def deep_convert_to_hash(object)
    case object
    when Hash
      object.each_with_object({}) { |(k, v), h| h[k] = deep_convert_to_hash(v) }
    when Array
      object.map { |v| deep_convert_to_hash(v) }
    else
      # ActiveSupport::OrderedOptions or similar respond to to_h
      if object.respond_to?(:to_h)
        deep_convert_to_hash(object.to_h)
      else
        object
      end
    end
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
      # Index array entries to keep stable keys
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
        # Force string keys in YAML output
        h[k.to_s] = mask_values(v)
      end
    when Array
      obj.map { |v| mask_values(v) }
    else
      # Blank out scalar values
      ""
    end
  end

  desc "Export masked credentials to config/credentials.example.yml"
  task export_example_yaml: :environment do
    root = Rails.application.credentials.respond_to?(:config) ? Rails.application.credentials.config : Rails.application.credentials
    creds = deep_convert_to_hash(root)
    masked = mask_values(creds)
    path = Rails.root.join("config", "credentials.example.yml")
    File.write(path, masked.to_yaml)
    # Remove older file name to avoid confusion
    old_path = Rails.root.join("config", "credentials.example.dump.yml")
    if File.exist?(old_path) && old_path.to_s != path.to_s
      begin
        File.delete(old_path)
      rescue StandardError
        # ignore cleanup errors
      end
    end
    puts "Wrote #{path}"
  end

  desc "Export flattened .env.from_credentials.example from credentials (values redacted)"
  task export_env_example: :environment do
    root = Rails.application.credentials.respond_to?(:config) ? Rails.application.credentials.config : Rails.application.credentials
    creds = deep_convert_to_hash(root)
    flattened = flatten_hash_to_env_keys(creds)
    lines = []
    lines << "# Generated from Rails credentials; values intentionally left blank"
    lines << "# Edit and copy to .env to use locally"
    flattened.keys.sort.each do |key|
      # Do not emit Rails internal keys that might appear
      next if key == "ENV"
      lines << "#{key}="
    end
    path = Rails.root.join(".env.from_credentials.example")
    File.write(path, lines.join("\n") + "\n")
    puts "Wrote #{path}"
  end
end
