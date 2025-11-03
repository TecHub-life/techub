# config/initializers/cors.rb
# Allow cross-origin requests from Next.js app

if defined?(Rack::Cors)
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins "localhost:3001", "127.0.0.1:3001", "http://localhost:3001", "http://127.0.0.1:3001"

      resource "/api/*",
        headers: :any,
        methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
        credentials: false
    end
  end
end
