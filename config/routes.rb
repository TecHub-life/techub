Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"

  get "/directory", to: "pages#directory"
  get "/directory/autocomplete", to: "pages#autocomplete"
  get "/leaderboards", to: "pages#leaderboards"
  get "/submit", to: "pages#submit"
  post "/submit", to: "submissions#create", as: :create_submission
  get "/faq", to: "pages#faq"
  get "/analytics", to: "pages#analytics"
  get "/docs", to: "pages#docs"
  get "/gallery", to: "pages#gallery"
  get "/api-docs", to: "api_docs#show"
  get "/api-docs/spec.yaml", to: "api_docs#spec", as: :api_docs_spec
  get "/motifs", to: "pages#motifs"
  # Account settings
  get "/settings/account", to: "accounts#edit", as: :edit_account
  patch "/settings/account", to: "accounts#update", as: :account

  # Gemini healthcheck
  get "/up/gemini", to: "gemini#up"
  get "/up/gemini/image", to: "gemini#image"

  get "/auth/github", to: "sessions#start", as: :auth_github
  get "/auth/github/callback", to: "sessions#callback", as: :auth_github_callback
  resource :session, only: :destroy

  namespace :github do
    post "/webhooks", to: "webhooks#receive"
  end

  # Raw profile routes
  get "/raw_profiles", to: "profiles#index", as: :raw_profiles
  get "/raw_profiles/:username", to: "profiles#show", as: :raw_profile

  # Friendly profile routes expected by tests
  get "/profiles", to: "profiles#index", as: :profiles
  get "/profiles/:username", to: "profiles#show", as: :profile
  get "/profiles/:username/status", to: "profiles#status", defaults: { format: :json }

  # Card preview routes (for screenshots)
  get "/cards/:login/og", to: "cards#og", as: :card_og
  get "/cards/:login/card", to: "cards#card", as: :card_preview
  get "/cards/:login/simple", to: "cards#simple", as: :card_simple
  get "/cards/:login/banner", to: "cards#banner", as: :card_banner
  get "/cards/leaderboard/og", to: "cards#leaderboard_og", as: :leaderboard_og

  # Ownership (My Profiles)
  get "/my/profiles", to: "my_profiles#index", as: :my_profiles
  delete "/my/profiles/:username", to: "my_profiles#destroy", as: :remove_my_profile
  get "/my/profiles/:username/settings", to: "my_profiles#settings", as: :my_profile_settings
  patch "/my/profiles/:username/settings", to: "my_profiles#update_settings", as: :update_my_profile_settings
  post "/my/profiles/:username/regenerate", to: "my_profiles#regenerate", as: :regenerate_my_profile
  post "/my/profiles/:username/regenerate_ai", to: "my_profiles#regenerate_ai", as: :regenerate_my_profile_ai
  post "/my/profiles/:username/upload_asset", to: "my_profiles#upload_asset", as: :upload_my_profile_asset
  post "/my/profiles/:username/select_asset", to: "my_profiles#select_asset", as: :select_my_profile_asset

  # Direct OG image route (serves/redirects image; enqueues generation if missing)
  get "/og/:login(.:format)", to: "og#show", as: :og_image, defaults: { format: :jpg }

  # Public JSON API for assets
  namespace :api do
    namespace :v1 do
      get "/profiles/:username/assets", to: "profiles#assets", defaults: { format: :json }
      get "/leaderboards", to: "leaderboards#index", defaults: { format: :json }
      get "/leaderboards/podium", to: "leaderboards#podium", defaults: { format: :json }
    end
  end

  # Ops admin (lightweight panel)
  namespace :ops do
    get "/", to: "admin#index", as: :admin
    post "/axiom_smoke", to: "admin#axiom_smoke", as: :axiom_smoke
    post "/send_test_email", to: "admin#send_test_email", as: :send_test_email
    post "/bulk_retry", to: "admin#bulk_retry", as: :bulk_retry
    post "/bulk_retry_ai", to: "admin#bulk_retry_ai", as: :bulk_retry_ai
    post "/bulk_retry_all", to: "admin#bulk_retry_all", as: :bulk_retry_all
    post "/bulk_retry_ai_all", to: "admin#bulk_retry_ai_all", as: :bulk_retry_ai_all
    resources :admin, only: [] do
      collection do
        post :rebuild_leaderboards
        post :capture_leaderboard_og
        post :backups_create
        post :backups_prune
        post :backups_doctor
        post :backups_doctor_write
      end
    end
    # Profiles admin actions
    get "/profiles/search", to: "profiles#search", as: :search_profiles
    get "/profiles/:username", to: "profiles#show", as: :profile_admin
    post "/profiles/:username/retry", to: "profiles#retry", as: :retry_profile
    post "/profiles/:username/retry_ai", to: "profiles#retry_ai", as: :retry_profile_ai
    delete "/profiles/:username", to: "profiles#destroy", as: :destroy_profile
    # Ownerships admin
    get "/ownerships", to: "ownerships#index", as: :ownerships
    post "/ownerships/set_owner", to: "ownerships#set_owner", as: :set_owner_ownership
    post "/ownerships/transfer_by_profile", to: "ownerships#transfer_by_profile", as: :transfer_by_profile_ownership
    post "/ownerships/:id/transfer", to: "ownerships#transfer", as: :transfer_ownership
    delete "/ownerships/:id", to: "ownerships#destroy", as: :destroy_ownership
    get "/users/search", to: "users#search", as: :search_users
    post "/profiles/:username/generate_social_assets", to: "profiles#generate_social_assets", as: :generate_social_assets
  end
  # Mission Control (Jobs UI)
  if defined?(MissionControl::Jobs::Engine)
    # Mount the engine. Auth is enforced inside the engine via
    # config/initializers/mission_control_jobs.rb (HTTP Basic).
    cred = Rails.application.credentials.dig(:mission_control, :jobs, :http_basic)
    basic = Rails.env.production? ? cred : (ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] || cred)

    if Rails.env.production?
      # Only expose in production when HTTP Basic credentials exist
      mount MissionControl::Jobs::Engine, at: "/ops/jobs" if basic.present?
    else
      # Always mount in non-production for local administration
      mount MissionControl::Jobs::Engine, at: "/ops/jobs"
    end
  else
    # Fallback lightweight jobs status when Mission Control is not installed
    namespace :ops do
      get "/jobs", to: "jobs#index"
    end
  end
end
