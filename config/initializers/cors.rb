# Allow CORS for API endpoints
# This enables the React battle viewer to call the TecHub API

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # In production, restrict to your React app's domain
    # origins 'https://battles.techub.life', 'https://techub.life'
    
    # For development, allow localhost
    origins '*'  # Change this in production!
    
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
end
