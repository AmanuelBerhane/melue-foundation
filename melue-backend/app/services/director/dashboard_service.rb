# frozen_string_literal: true

module Director
  # SCR-DIR-001 — Director Dashboard.
  # Live operational counts for the current day: who is in session right now,
  # how today's schedule looks (FR-119, FR-125) and what is waiting on review.
  class DashboardService < ApplicationService
    ACTIVE_STUDENT_STATUSES = %w[active active_therapy].freeze

    def initialize(date: Date.current)
      @date = date
    end

    def call
      success({
        date: @date.iso8601,
        generated_at: Time.current.iso8601,
        students: student_counts,
        staff: staff_counts,
        sessions: session_counts,
        scheduling: scheduling_counts,
        reviews: review_counts,
        activity: activity_counts
      })
    end

    private

    def day_range
      @date.all_day
    end

    def active_student_ids
      @active_student_ids ||= Student.kept.where(status: ACTIVE_STUDENT_STATUSES).pluck(:id)
    end

    def todays_assignments
      TeacherStudentAssignment.kept.scheduled.for_date(@date)
    end

    def student_counts
      {
        total_active: active_student_ids.size,
        in_assessment: Student.kept.where(status: "in_assessment").count,
        ready_for_iup: Student.kept.where(status: %w[assessment_complete ready_for_iup]).count
      }
    end

    def staff_counts
      teacher_ids = StaffMember.kept.role_teacher.pluck(:id)
      unavailable_ids = StaffAvailability.for_date(@date).where(staff_member_id: teacher_ids).distinct.pluck(:staff_member_id)
      on_duty_ids = todays_assignments.where(teacher_id: teacher_ids).distinct.pluck(:teacher_id)

      {
        total_teachers: teacher_ids.size,
        teachers_on_duty: on_duty_ids.size,
        teachers_unavailable: unavailable_ids.size
      }
    end

    def session_counts
      in_progress = TherapySession.kept.in_progress

      {
        in_progress: in_progress.count,
        students_in_session: SessionParticipant.kept.where(therapy_session_id: in_progress.select(:id)).count,
        rooms_in_use: in_progress.distinct.count(:therapy_room_id),
        completed_today: TherapySession.kept.status_completed.where(ended_at: day_range).count
      }
    end

    def scheduling_counts
      assigned_ids = todays_assignments.distinct.pluck(:student_id)

      {
        assignments_today: todays_assignments.count,
        students_scheduled_today: assigned_ids.size,
        unassigned_active_students: (active_student_ids - assigned_ids).size,
        capacity_per_teacher: SessionScheduleConfig.instance.staff_to_student_capacity
      }
    end

    def review_counts
      {
        session_summaries_pending_review: SessionSummary.status_submitted.count,
        mastery_checks_pending_approval: GoalMasteryCheck.status_pending_approval.count
      }
    end

    def activity_counts
      {
        trials_logged_today: Trial.kept.where(logged_at: day_range).count,
        behavior_incidents_today: BehaviorIncident.where(occurred_at: day_range).count,
        goals_mastered_this_month: StudentGoal.kept.status_mastered.where(updated_at: @date.all_month).count
      }
    end
  end
end
