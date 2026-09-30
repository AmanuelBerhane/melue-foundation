# frozen_string_literal: true

module TherapyCoordinator
  class TeacherPerformanceMetricsService < ApplicationService
    attr_reader :params, :current_user

    def initialize(params = {}, current_user = nil)
      @params = params
      @current_user = current_user
    end

    def call
      start_date = parse_date(params[:start_date])
      end_date = parse_date(params[:end_date])

      if params[:teacher_id].present?
        teacher = StaffMember.find_by(id: params[:teacher_id])
        return failure("Teacher not found") unless teacher

        metrics = compute_metrics_for_teacher(teacher, start_date, end_date)
        success(metrics)
      else
        teachers = StaffMember.where(role: [ "teacher", "therapy_coordinator" ]).order(:full_name)
        metrics_list = teachers.map do |teacher|
          compute_metrics_for_teacher(teacher, start_date, end_date)
        end
        success(metrics_list)
      end
    end

    private

    def parse_date(raw_date)
      return nil if raw_date.blank?

      raw_date.is_a?(Date) ? raw_date : Date.parse(raw_date.to_s)
    rescue ArgumentError
      nil
    end

    def compute_metrics_for_teacher(teacher, start_date, end_date)
      # 1. Sessions Completed
      sessions_scope = TherapySession.where(teacher_id: teacher.id, status: :completed)
      if start_date.present? && end_date.present?
        sessions_scope = sessions_scope.where(
          "started_at >= :start_time AND started_at <= :end_time",
          start_time: start_date.beginning_of_day,
          end_time: end_date.end_of_day
        )
      elsif start_date.present?
        sessions_scope = sessions_scope.where("started_at >= ?", start_date.beginning_of_day)
      elsif end_date.present?
        sessions_scope = sessions_scope.where("started_at <= ?", end_date.end_of_day)
      end

      completed_sessions_count = sessions_scope.count
      session_ids = sessions_scope.pluck(:id)

      # 2. Trials Logged & Average per Session
      trials_scope = Trial.where(therapy_session_id: session_ids)
      total_trials = trials_scope.count
      avg_trials_per_session = completed_sessions_count.positive? ? (total_trials.to_f / completed_sessions_count).round(2) : 0.0

      # 3. Student Independence Percentage (Average)
      # Independent trial = outcome == 'correct' AND (prompt_levels.label == '+' OR prompt_label_snapshot == '+')
      independent_trials_count = trials_scope
        .left_joins(:prompt_level)
        .where(outcome: "correct")
        .where("trials.prompt_label_snapshot = :plus OR prompt_levels.label = :plus", plus: "+")
        .count

      avg_independence_percentage = total_trials.positive? ? ((independent_trials_count.to_f / total_trials) * 100).round(2) : 0.0

      # 4. Incident Rate
      incidents_scope = BehaviorIncident.where(staff_member_id: teacher.id)
      incidents_scope = incidents_scope.or(BehaviorIncident.where(therapy_session_id: session_ids)) if session_ids.any?
      if start_date.present? && end_date.present?
        incidents_scope = incidents_scope.where(occurred_at: start_date.beginning_of_day..end_date.end_of_day)
      elsif start_date.present?
        incidents_scope = incidents_scope.where("occurred_at >= ?", start_date.beginning_of_day)
      elsif end_date.present?
        incidents_scope = incidents_scope.where("occurred_at <= ?", end_date.end_of_day)
      end
      total_incidents = incidents_scope.distinct.count
      incident_rate = completed_sessions_count.positive? ? (total_incidents.to_f / completed_sessions_count).round(2) : 0.0

      # 5. Review Status
      summaries = SessionSummary.where(therapy_session_id: session_ids)
      draft_count = summaries.where(status: :draft).count
      submitted_count = summaries.where(status: :submitted).count
      reviewed_count = summaries.where(status: :reviewed).count
      missing_count = [ completed_sessions_count - summaries.count, 0 ].max

      overall_review_status = if completed_sessions_count.zero?
        "no_sessions"
      elsif submitted_count.positive?
        "pending_review"
      elsif draft_count.positive? || missing_count.positive?
        "in_progress"
      else
        "all_reviewed"
      end

      {
        teacher_id: teacher.id,
        teacher_name: teacher.full_name,
        teacher_role: teacher.role,
        staff_number: teacher.staff_number,
        sessions_completed: completed_sessions_count,
        total_trials: total_trials,
        average_trials_per_session: avg_trials_per_session,
        average_independence_percentage: avg_independence_percentage,
        total_incidents: total_incidents,
        incident_rate: incident_rate,
        review_status: {
          overall_status: overall_review_status,
          submitted_count: submitted_count,
          reviewed_count: reviewed_count,
          draft_count: draft_count,
          missing_count: missing_count,
          pending_review_count: submitted_count
        }
      }
    end
  end
end
