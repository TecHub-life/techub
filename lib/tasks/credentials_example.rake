namespace :credentials do
  desc "Generate config/credentials.example.yml with google block"
  task example: :environment do
    example = {
      "secret_key_base" => "",
      "github" => {
        "app_id" => "",
        "client_id" => "",
        "client_secret" => "",
        "installation_id" => "",
        "private_key" => ""
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
      "google" => {
        "project_id" => "",
        "location" => "us-central1",
        "application_credentials_json" => <<~JSON
          {
            "type": "service_account",
            "project_id": "",
            "private_key_id": "",
            "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
            "client_email": "",
            "client_id": "",
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "client_x509_cert_url": ""
          }
        JSON
      }
    }

    require "yaml"
    File.write(Rails.root.join("config", "credentials.example.yml"), example.to_yaml)
    puts "Wrote config/credentials.example.yml"
  end
end
