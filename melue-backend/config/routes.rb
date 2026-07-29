Rails.application.routes.draw do
  # Health check — used by load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      # Mount versioned routes here.
    end
  end
  mount OasRails::Engine => "/docs"
end
