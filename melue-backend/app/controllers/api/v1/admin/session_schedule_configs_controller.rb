module Api
  module V1
    module Admin
      class SessionScheduleConfigsController < BaseController
        def show
          config = SessionScheduleConfig.instance
          render json: config
        end

        def update
          config = SessionScheduleConfig.instance

          if config.update(config_params)
            render json: config
          else
            render json: { errors: config.errors }, status: :unprocessable_entity
          end
        end

        private

        def config_params
          params.require(:session_schedule_config).permit(
            :morning_start_time,
            :morning_end_time,
            :afternoon_start_time,
            :afternoon_end_time,
            :pre_therapy_duration_minutes,
            :station_1_duration_minutes,
            :station_2_duration_minutes,
            :staff_to_student_capacity,
            :draft_expiry_days
          )
        end
      end
    end
  end
end
