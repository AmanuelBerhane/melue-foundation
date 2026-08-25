module Reports
  class SessionSummariesService < ApplicationService
    def initialize(params = {})
      @start_date = params[:start_date]
      @end_date = params[:end_date]
      @teacher_id = params[:teacher_id]
      @station_id = params[:station_id]
      @student_id = params[:student_id]
      @sort_by = params[:sort_by] || "started_at"
      @sort_direction = params[:sort_direction] || "desc"
    end

    def call
      sessions = fetch_sessions
      success(format_sessions(sessions))
    rescue StandardError => e
      failure(e.message)
    end

    private

    def fetch_sessions
      # Only fetch completed sessions
      query = TherapySession.where(status: "completed").includes(:teacher, :therapy_station, session_participants: :student)

      query = query.where("started_at >= ?", Date.parse(@start_date).beginning_of_day) if @start_date.present?
      query = query.where("ended_at <= ?", Date.parse(@end_date).end_of_day) if @end_date.present?
      query = query.where(teacher_id: @teacher_id) if @teacher_id.present?
      query = query.where(therapy_station_id: @station_id) if @station_id.present?

      if @student_id.present?
        query = query.joins(:session_participants).where(session_participants: { student_id: @student_id })
      end

      # Validating sort_by to prevent SQL injection
      allowed_sort_columns = %w[started_at ended_at created_at updated_at]
      sort_column = allowed_sort_columns.include?(@sort_by) ? @sort_by : "started_at"
      sort_dir = %w[asc desc].include?(@sort_direction.downcase) ? @sort_direction.downcase : "desc"

      query.order(sort_column => sort_dir)
    end

    def format_sessions(sessions)
      sessions.map do |session|
        {
          id: session.id,
          status: session.status,
          started_at: session.started_at,
          ended_at: session.ended_at,
          duration_minutes: duration_for(session),
          teacher: {
            id: session.teacher_id,
            name: session.teacher&.full_name
          },
          station: {
            id: session.therapy_station_id,
            name: session.therapy_station&.name
          },
          students: session.session_participants.map do |participant|
            {
              id: participant.student_id,
              name: "#{participant.student&.first_name} #{participant.student&.last_name}"
            }
          end
        }
      end
    end

    def duration_for(session)
      return 0 unless session.started_at && session.ended_at
      ((session.ended_at - session.started_at) / 60).round
    end
  end
end
