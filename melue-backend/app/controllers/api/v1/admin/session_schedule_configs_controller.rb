module Api
  module V1
    module Admin
      class SessionScheduleConfigsController < BaseController
        wrap_parameters false

        def show
          config = SessionScheduleConfig.instance
          render json: serialize_config(config)
        end

        def update
          config = SessionScheduleConfig.instance

          if config.update(config_params)
            render json: serialize_config(config)
          else
            render json: { errors: config.errors }, status: :unprocessable_entity
          end
        end

        private

        def serialize_config(config)
          config.as_json.merge(
            "morningStart" => config.morning_start_time&.strftime("%I:%M %p"),
            "morningEnd" => config.morning_end_time&.strftime("%I:%M %p"),
            "afternoonStart" => config.afternoon_start_time&.strftime("%I:%M %p"),
            "afternoonEnd" => config.afternoon_end_time&.strftime("%I:%M %p"),
            "preTherapyDuration" => config.pre_therapy_duration_minutes,
            "station1Duration" => config.station_1_duration_minutes,
            "station2Duration" => config.station_2_duration_minutes,
            "capacity" => config.staff_to_student_capacity,
            "draftExpiry" => config.draft_expiry_days
          )
        end

        def config_params
          cfg = params[:session_schedule_config].presence || params
          get_val = ->(*keys) { keys.map { |k| cfg[k].presence || params[k].presence }.compact.first }

          transformed = {}

          m_start = get_val.(:morningStart, :morningStartTime, "morningStart", "morningStartTime")
          m_end   = get_val.(:morningEnd, :morningEndTime, "morningEnd", "morningEndTime")
          a_start = get_val.(:afternoonStart, :afternoonStartTime, "afternoonStart", "afternoonStartTime")
          a_end   = get_val.(:afternoonEnd, :afternoonEndTime, "afternoonEnd", "afternoonEndTime")
          pre_dur = get_val.(:preTherapyDuration, :preTherapyDurationMinutes, "preTherapyDuration", "preTherapyDurationMinutes")
          s1_dur  = get_val.(:station1Duration, :station1DurationMinutes, "station1Duration", "station1DurationMinutes")
          s2_dur  = get_val.(:station2Duration, :station2DurationMinutes, "station2Duration", "station2DurationMinutes")
          cap     = get_val.(:capacity, :staffToStudentCapacity, "capacity", "staffToStudentCapacity")
          draft   = get_val.(:draftExpiry, :draftExpiryDays, "draftExpiry", "draftExpiryDays")

          transformed[:morning_start_time] = m_start if m_start.present?
          transformed[:morning_end_time] = m_end if m_end.present?
          transformed[:afternoon_start_time] = a_start if a_start.present?
          transformed[:afternoon_end_time] = a_end if a_end.present?
          transformed[:pre_therapy_duration_minutes] = pre_dur if pre_dur.present?
          transformed[:station_1_duration_minutes] = s1_dur if s1_dur.present?
          transformed[:station_2_duration_minutes] = s2_dur if s2_dur.present?
          transformed[:staff_to_student_capacity] = cap if cap.present?
          transformed[:draft_expiry_days] = draft if draft.present?

          permitted = cfg.permit(
            :morning_start_time,
            :morning_end_time,
            :afternoon_start_time,
            :afternoon_end_time,
            :pre_therapy_duration_minutes,
            :station_1_duration_minutes,
            :station_2_duration_minutes,
            :staff_to_student_capacity,
            :draft_expiry_days
          ).to_h.symbolize_keys

          permitted.merge(transformed)
        end
      end
    end
  end
end
