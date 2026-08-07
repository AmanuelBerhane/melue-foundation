Rails.application.routes.draw do
  # Health check — used by load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      namespace :admin do
        resources :goal_domains do
          put :reorder, on: :collection
        end

        resources :prompt_levels do
          put :reorder, on: :collection
        end

        resources :session_block_definitions

        resources :abc_dropdown_options do
          put :reorder, on: :collection
        end

        resources :form_configurations do
          member do
            post :import
            get :export
          end
        end

        resource :session_schedule_config, only: %i[show update]
      end

      # Today's session dashboard context
      get "today/session", to: "therapy_sessions#today_session"

      resources :therapy_sessions, only: %i[show] do
        # Start a session from an assignment
        post :start, on: :collection

        # Full dashboard payload (station, room, timer, cards, goals, streams)
        get :dashboard, on: :member

        # Update the focused goal for a participant (FR-092)
        patch "participants/:participant_id/active_goal",
              to: "therapy_sessions#update_active_goal",
              as: :participant_active_goal

        # Trial logging and stream (FR-093, FR-094)
        scope module: :therapy_sessions do
          resources :trials, only: %i[create] do
            get :stream, on: :collection
          end
        end
      end
    end
  end
  mount OasRails::Engine => "/docs"
end
