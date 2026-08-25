module Reports
  class StudentProgressService < ApplicationService
    def initialize(student_id:, start_date: nil, end_date: nil)
      @student_id = student_id
      @start_date = start_date ? Date.parse(start_date) : 6.months.ago.to_date
      @end_date = end_date ? Date.parse(end_date) : Date.today
    end

    def call
      student = Student.find_by(id: @student_id)
      return failure("Student not found") unless student

      # Validate sufficient data (e.g. at least one session in the period)
      sessions_count = SessionParticipant.where(student_id: student.id)
                                         .joins(:therapy_session)
                                         .where(therapy_sessions: { started_at: @start_date.beginning_of_day..@end_date.end_of_day })
                                         .count

      # FR-130: Flag indicating if sufficient data exists for a proper bi-annual report
      sufficient_data = sessions_count > 0

      success({
        student: {
          id: student.id,
          name: "#{student.first_name} #{student.last_name}",
          program_type: student.program_type
        },
        report_period: {
          start_date: @start_date,
          end_date: @end_date
        },
        sufficient_data_available: sufficient_data,
        assessment_summary: assessment_summary(student),
        current_goals: current_goals(student),
        session_history_stats: {
          total_sessions: sessions_count
        },
        behavior_incident_trends: [], # TODO: Requires ABC incident modeling
        goal_progress_charts: [] # TODO: Export graph data points for UI
      })
    rescue StandardError => e
      failure(e.message)
    end

    private

    def assessment_summary(student)
      # Fetch the latest assessment cycle
      cycle = AssessmentCycle.where(student_id: student.id).order(created_at: :desc).first
      return nil unless cycle

      {
        status: cycle.status,
        started_on: cycle.started_on,
        completed_on: cycle.completed_on
      }
    end

    def current_goals(student)
      student.student_goals.includes(:goal).map do |sg|
        {
          id: sg.id,
          name: sg.goal&.name,
          status: sg.status,
          progress_percent: sg.progress_percent,
          clinical_note: sg.clinical_note
        }
      end
    end
  end
end
