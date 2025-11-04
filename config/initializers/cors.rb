# config/initializers/cors.rb

if defined?(Rack::Cors)
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins "localhost:3001",
              "127.0.0.1:3001",
              "http://localhost:3001",
              "http://127.0.0.1:3001",
              "https://techub-battles.vercel.app",
              %r{\Ahttps?://([a-z0-9-]+\.)*techub\.life\z}i,
              %r{\Ahttps?://([a-z0-9-]+\.)*vercel\.app\z}i,
              %r{\Ahttps?://([a-z0-9-]+\.)*pages\.dev\z}i,
              %r{\Ahttps?://([a-z0-9-]+\.)*github\.io\z}i

      resource "/api/*",
        headers: :any,
        methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
        credentials: false
    end
  end
end
