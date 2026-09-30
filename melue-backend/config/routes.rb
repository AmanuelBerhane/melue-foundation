# config/routes.rb
Rails.application.routes.draw do
  # Health check — used by load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :notifications, only: [ :index ] do
        member { post :mark_as_read }
      end

      resources :student_goals, only: [] do
        resources :mastery_checks, only: [ :create ], controller: "goal_mastery_checks"
      end

      resources :mastery_checks, only: [ :show ], controller: "goal_mastery_checks" do
        member do
          patch :approve
          patch :reject
        end
        resources :verifications, only: [ :create ], controller: "goal_mastery_verifications"
      end

      # --- Admin Routes ---
      namespace :admin do
        resources :roles
        resources :staff_members, only: %i[index show update] do
          member do
            put :update_status
            post :reset_password
          end
        end

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
      resources :students, only: %i[index show create update] do
        member do
          get :progress_monitoring, to: "student_progress#show"
          get :progress_report, to: "student_progress#progress_report"
        end
        resources :internal_notes, controller: "internal_student_notes", only: %i[index create update destroy]
      end

      # Assessment workflow endpoints (FR-034, FR-035, FR-036)
      get  "assessments/dashboard", to: "assessments#dashboard"
      post "assessments/launch",    to: "assessments#launch"

      # Today's session dashboard context
      get "today/session", to: "therapy_sessions#today_session"

      resources :therapy_sessions, only: %i[show] do
        post :swap, on: :member
        post :start, on: :collection
        get :dashboard, on: :member
        patch "participants/:participant_id/active_goal",
              to: "therapy_sessions#update_active_goal",
              as: :participant_active_goal

        scope module: :therapy_sessions do
          resources :trials, only: %i[create] do
            get :stream, on: :collection
          end

          resource :summary, only: %i[show], controller: :session_summaries do
            patch :draft
            post :submit
            post :preview_pdf
          end

          get "participants/:participant_id/goals/:student_goal_id/trial_log",
              to: "trial_logs#show",
              as: :participant_goal_trial_log
        end
      end

      namespace :therapy_coordinator do
        resources :session_summaries, only: %i[index] do
          patch :review, on: :member
        end

        # Operational Management (SCR-TC-005: FR-121, FR-122, FR-123, FR-124, FR-125)
        get  "operational_management",                     to: "operational_management#index"
        post "operational_management/reassign",            to: "operational_management#reassign"
        get  "operational_management/performance_metrics", to: "operational_management#performance_metrics"
        get  "operational_management/unassigned_alerts",   to: "operational_management#unassigned_alerts"

        resources :staff_availabilities, only: %i[index create destroy]
      end

      # Staff Unavailability shortcuts (Domain Model)
      get  "staff/:staff_id/unavailability", to: "therapy_coordinator/staff_availabilities#index"
      post "staff/:staff_id/unavailability", to: "therapy_coordinator/staff_availabilities#create"

      namespace :program_director do
        get :dashboard, to: "dashboard#show"
        get :assessment_pipeline, to: "assessment_pipeline#index"
        resources :assessments, only: %i[index show]
      end

      resources :sensory_activities, only: [ :index ]
      resources :sensory_assessments, only: [ :create, :update, :show ] do
        member do
          post :submit
        end
      end

      resources :preference_inventory_items, only: %i[index]

      resources :assessment_cycles, only: [] do
        resource :preference_assessment, only: %i[show create] do
          post :submit
          get :rankings
          scope module: :preference_assessments do
            resources :observations, only: %i[create update destroy]
          end
        end

        # Exactly one ABLLS assessment per cycle (FR-037, FR-038, FR-039, FR-040)
        resource :ablls_assessment, only: %i[show create]
      end

      # ABLLS assessment response management & completion
      resources :ablls_assessments, only: [], param: :id do
        member do
          post :complete
          patch "responses/bulk", action: "bulk_update_responses"
          patch "responses/:response_id", action: "update_response", as: :response
        end
      end

      # ABLLS score metadata endpoint
      get "ablls_assessments/score_options", to: "ablls_assessments#score_options"

      # Offline Sync Endpoints
      scope :sync do
        get :pull, to: "syncs#pull"
        post :push, to: "syncs#push"
      end

      resources :iups do
        member do
          get :validate
          post :finalize
        end
        resources :goals, only: [ :create, :update, :destroy ], controller: "iup_goals"
        resources :signatures, only: [ :create ], controller: "iup_signatures"
      end

      resources :goal_domains, only: %i[index show]

      resources :goals do
        collection do
          get :search
          post :upload_template
          post :import_template
        end
        member do
          patch :deactivate
          patch :activate
        end
      end
    end
  end

  namespace :api do
    namespace :v1 do
      # Enrollments
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

      # Behavior Assessment (MR-23)
      namespace :assessments do
        resources :mass, only: [ :create, :update ] do
          member { post :submit }
        end

        resources :fast, only: [ :create, :update ] do
          member { post :submit }
        end
      end

      # Student Goals - GET /api/v1/students/:student_id/goals
      # This shows the goal summary for a student (not a specific goal)
      get "students/:student_id/goals", to: "students/goals#show"

      # ========================================
      # FIXED: Behavior Incidents (FR-045, FR-046)
      # ========================================
      # GET /api/v1/students/:student_id/behavior_incidents
      resources :students, only: [] do
        resources :behavior_incidents, only: [ :index, :create, :update, :destroy ],
                                        controller: "students/behavior_incidents"
      end

      # Student Charts - All chart endpoints under student
      # GET /api/v1/students/:student_id/charts/goal_progress
      # GET /api/v1/students/:student_id/charts/trial_distribution
      # GET /api/v1/students/:student_id/charts/behavior_trends
      # GET /api/v1/students/:student_id/charts/assessment_summary
      # POST /api/v1/students/:student_id/charts/export
      # POST /api/v1/students/:student_id/charts/share
      get "students/:student_id/charts/goal_progress", to: "students/charts#goal_progress"
      get "students/:student_id/charts/trial_distribution", to: "students/charts#trial_distribution"
      get "students/:student_id/charts/behavior_trends", to: "students/charts#behavior_trends"
      get "students/:student_id/charts/assessment_summary", to: "students/charts#assessment_summary"
      post "students/:student_id/charts/export", to: "students/charts#export"
      post "students/:student_id/charts/share", to: "students/charts#share"

      # Staff Scheduling
      resources :staff_scheduling, only: [ :index ] do
        collection do
          get :teacher_schedule
          get :capacity
        end
      end

      resources :assignments, only: [ :create, :update, :destroy ], controller: "staff_scheduling"

      # Program Director Caseload
      namespace :program_directors do
        resources :caseload, only: [ :index ]
      end

      # Goal Assignments (top-level - doesn't need student_id)
      resources :goal_assignments, only: [ :create, :destroy ] do
        member do
          put :replace
        end
      end

      # Reports
      namespace :reports do
        get :foundation_overview
        get :session_summaries
        get :weekly_summaries
        get :student_progress
      end

      # ── Parent (Guardian) Portal ─────────────────────────────────────────────
      namespace :parent do
        # High-level overview: guardian profile, all children, unread counts
        get "dashboard", to: "dashboard#index"

        # Children list and individual child profile
        resources :students, only: %i[index show] do
          # Submitted/reviewed session history for this child
          resources :sessions, only: [ :index ], controller: "sessions"

          # Guardian-submitted home updates
          resources :home_observations, only: %i[index create], controller: "home_observations"

          # Staff ↔ guardian message thread for this child
          resources :communications, only: %i[index create], controller: "communications"
        end

        # Mark a specific message as read (no student_id nesting needed)
        resources :communications, only: [] do
          member { patch :mark_read }
        end
      end
    end
  end

  mount OasRails::Engine => "/docs"
end
