# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "http://localhost:8081,http://127.0.0.1:8081").split(",").map(&:strip)
    if Rails.env.development?
      origins(*allowed_origins, /https?:\/\/localhost(:\d+)?/, /https?:\/\/127\.0\.0\.1(:\d+)?/, /https?:\/\/10\.\d+\.\d+\.\d+(:\d+)?/, /https?:\/\/192\.168\.\d+\.\d+(:\d+)?/)
    else
      origins(*allowed_origins)
    end

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization" ]
  end
end
