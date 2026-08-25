module Reports
  class WeeklySummariesService < ApplicationService
    def initialize(params = {})
      @start_date = params[:start_date] ? Date.parse(params[:start_date]).beginning_of_week : Date.today.beginning_of_week
      @end_date = params[:end_date] ? Date.parse(params[:end_date]).end_of_week : Date.today.end_of_week
      @student_id = params[:student_id]
      @teacher_id = params[:teacher_id]
    end

    def call
      success(fetch_weekly_summaries)
    rescue StandardError => e
      failure(e.message)
    end

    private

    def fetch_weekly_summaries
      query = TherapySession.where(status: "completed")
                            .where(started_at: @start_date.beginning_of_day..@end_date.end_of_day)

      query = query.where(teacher_id: @teacher_id) if @teacher_id.present?

      if @student_id.present?
        query = query.joins(:session_participants).where(session_participants: { student_id: @student_id })
      end

      # Group sessions by the start of their respective week
      sessions_by_week = query.group_by { |session| session.started_at.to_date.beginning_of_week }

      sessions_by_week.map do |week_start, sessions|
        {
          week_start: week_start,
          week_end: week_start.end_of_week,
          total_sessions: sessions.size,
          total_duration_minutes: sessions.sum { |s| duration_for(s) },
          sessions_included: sessions.map do |s|
            {
              id: s.id,
              date: s.started_at.to_date,
              teacher_id: s.teacher_id
              # consolidated_notes: In the future, pull the teacher_qualitative_notes from the session summary
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
