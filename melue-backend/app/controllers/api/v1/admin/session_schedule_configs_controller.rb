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
            # Synchronize session sub-blocks if provided
            raw_blocks = params[:blocks].presence || params.dig(:session_schedule_config, :blocks)
            if raw_blocks.is_a?(Array)
              raw_blocks.each do |blk|
                name = blk[:name] || blk["name"]
                s_time = blk[:startTime] || blk["startTime"]
                e_time = blk[:endTime] || blk["endTime"]
                next if name.blank? || s_time.blank? || e_time.blank?

                b = SessionBlockDefinition.find_by(name: name) ||
                    (blk[:id].present? && blk[:id].to_s.length > 10 ? SessionBlockDefinition.find_by(id: blk[:id]) : nil) ||
                    SessionBlockDefinition.new(name: name)

                b.name = name
                b.start_time = s_time
                b.end_time = e_time
                b.round = name.to_s.downcase.include?("afternoon") ? "afternoon" : "morning"
                b.is_active = true
                b.save if b.valid?
              end
            end

            render json: serialize_config(config)
          else
            render json: { errors: config.errors }, status: :unprocessable_content
          end
        end

        private

        def serialize_config(config)
          block_defs = SessionBlockDefinition.active.ordered
          serialized_blocks = block_defs.map do |b|
            {
              "id" => b.id.to_s,
              "name" => b.name,
              "startTime" => b.start_time&.strftime("%I:%M %p"),
              "endTime" => b.end_time&.strftime("%I:%M %p"),
              "round" => b.round
            }
          end

          config.as_json.merge(
            "morningStart" => config.morning_start_time&.strftime("%I:%M %p"),
            "morningStartTime" => config.morning_start_time&.strftime("%I:%M %p"),
            "morningEnd" => config.morning_end_time&.strftime("%I:%M %p"),
            "morningEndTime" => config.morning_end_time&.strftime("%I:%M %p"),
            "afternoonStart" => config.afternoon_start_time&.strftime("%I:%M %p"),
            "afternoonStartTime" => config.afternoon_start_time&.strftime("%I:%M %p"),
            "afternoonEnd" => config.afternoon_end_time&.strftime("%I:%M %p"),
            "afternoonEndTime" => config.afternoon_end_time&.strftime("%I:%M %p"),
            "preTherapyDuration" => config.pre_therapy_duration_minutes,
            "preTherapyDurationMinutes" => config.pre_therapy_duration_minutes,
            "station1Duration" => config.station_1_duration_minutes,
            "station1DurationMinutes" => config.station_1_duration_minutes,
            "station2Duration" => config.station_2_duration_minutes,
            "capacity" => config.staff_to_student_capacity,
            "staffToStudentCapacity" => config.staff_to_student_capacity,
            "staff_to_student_capacity" => config.staff_to_student_capacity,
            "draftExpiry" => config.draft_expiry_days,
            "draftExpiryDays" => config.draft_expiry_days,
            "draft_expiry_days" => config.draft_expiry_days,
            "blocks" => serialized_blocks
          )
        end

        def config_params
          cfg = params[:session_schedule_config].presence || params
          get_val = ->(*keys) { keys.map { |k| cfg[k].presence || params[k].presence }.compact.first }

          transformed = {}

          m_start = get_val.(:morningStart, :morningStartTime, :morning_start, "morningStart", "morningStartTime", "morning_start")
          m_end   = get_val.(:morningEnd, :morningEndTime, :morning_end, "morningEnd", "morningEndTime", "morning_end")
          a_start = get_val.(:afternoonStart, :afternoonStartTime, :afternoon_start, "afternoonStart", "afternoonStartTime", "afternoon_start")
          a_end   = get_val.(:afternoonEnd, :afternoonEndTime, :afternoon_end, "afternoonEnd", "afternoonEndTime", "afternoon_end")
          pre_dur = get_val.(:preTherapyDuration, :preTherapyDurationMinutes, :pre_therapy_duration, "preTherapyDuration", "preTherapyDurationMinutes", "pre_therapy_duration")
          s1_dur  = get_val.(:station1Duration, :station1DurationMinutes, :station_1_duration, :station1_duration, "station1Duration", "station1DurationMinutes", "station_1_duration", "station1_duration")
          s2_dur  = get_val.(:station2Duration, :station2DurationMinutes, :station_2_duration, :station2_duration, "station2Duration", "station2DurationMinutes", "station_2_duration", "station2_duration")
          cap     = get_val.(:capacity, :staffToStudentCapacity, :staffCapacity, :staff_capacity, "capacity", "staffToStudentCapacity", "staffCapacity", "staff_capacity")
          draft   = get_val.(:draftExpiry, :draftExpiryDays, :draft_expiry, "draftExpiry", "draftExpiryDays", "draft_expiry")

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
