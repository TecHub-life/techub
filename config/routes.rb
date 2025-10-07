Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"

  get "/directory", to: "pages#directory"
  get "/leaderboards", to: "pages#leaderboards"
  get "/submit", to: "pages#submit"
  get "/faq", to: "pages#faq"
  get "/analytics", to: "pages#analytics"
  get "/docs", to: "pages#docs"

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
end
