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
      # Student registration and management
      resources :students, only: %i[index show create update]

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

      # Preference item catalogue for SCR-012 (FR-047a)
      resources :preference_inventory_items, only: %i[index]

      resources :assessment_cycles, only: [] do
        # Exactly one preference assessment per cycle (FR-047, FR-049)
        resource :preference_assessment, only: %i[show create] do
          # Finalise the assessment (FR-036)
          post :submit

          # Ranked top-preferences list (FR-047d, FR-048)
          get :rankings

          # Timer, counter, notes and custom items (FR-047b, FR-047e, FR-047f)
          scope module: :preference_assessments do
            resources :observations, only: %i[create update destroy]
          end
        end
      end
    end
  end

  namespace :api do
    namespace :v1 do
      resources :enrollments, only: [ :create, :show, :update ] do
        member do
          patch :update_step
          post :complete
          post :save_draft
          post :attach_document
          post :upload_photo
          post :upload_video
          delete :remove_photo
          delete :remove_video
        end
      end

      resources :staff_scheduling, only: [ :index ] do
        collection do
          get :teacher_schedule
          get :capacity
        end
      end

      resources :assignments, only: [ :create, :update, :destroy ], controller: "staff_scheduling"
    end
  end

  mount OasRails::Engine => "/docs"
end
