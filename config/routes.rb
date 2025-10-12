Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"

  get "/directory", to: "pages#directory"
  get "/leaderboards", to: "pages#leaderboards"
  get "/submit", to: "pages#submit"
  post "/submit", to: "submissions#create", as: :create_submission
  get "/faq", to: "pages#faq"
  get "/analytics", to: "pages#analytics"
  get "/docs", to: "pages#docs"

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

  # Ownership (My Profiles) — index and create/destroy will come later
  # get "/my/profiles", to: "my_profiles#index", as: :my_profiles

  # Card previews for screenshotting (HTML views sized for capture)
  get "/cards/:login/og", to: "cards#og", as: :card_og
  get "/cards/:login/card", to: "cards#card", as: :card_preview
  get "/cards/:login/simple", to: "cards#simple", as: :card_simple
  # Mission Control (Jobs UI) — only mount when gem is present
  if defined?(MissionControl::Jobs::Engine)
    basic = ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] || (Rails.application.credentials.dig(:mission_control, :jobs, :http_basic) rescue nil)
    if basic.present?
      user, pass = basic.to_s.split(":", 2)
      authenticator = lambda do |u, p|
        ActiveSupport::SecurityUtils.secure_compare(u.to_s, user.to_s) & ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass.to_s)
      end
      constraints = lambda { |req| ActionController::HttpAuthentication::Basic.authenticate(req, &authenticator) }
      constraints(constraints) { mount MissionControl::Jobs::Engine, at: "/ops/jobs" }
    else
      mount MissionControl::Jobs::Engine, at: "/ops/jobs"
    end
  end


  # Mission Control (Jobs UI) — only mount when gem is present
  if defined?(MissionControl::Jobs::Engine)
    basic = ENV["MISSION_CONTROL_JOBS_HTTP_BASIC"] || (Rails.application.credentials.dig(:mission_control, :jobs, :http_basic) rescue nil)
    if basic.present?
      user, pass = basic.to_s.split(":", 2)
      authenticator = lambda do |u, p|
        ActiveSupport::SecurityUtils.secure_compare(u.to_s, user.to_s) & ActiveSupport::SecurityUtils.secure_compare(p.to_s, pass.to_s)
      end
      constraints = lambda { |req| ActionController::HttpAuthentication::Basic.authenticate(req, &authenticator) }
      constraints(constraints) { mount MissionControl::Jobs::Engine, at: "/ops/jobs" }
    else
      mount MissionControl::Jobs::Engine, at: "/ops/jobs"
    end
  end
end
