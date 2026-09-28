# frozen_string_literal: true

module Assessments
  class DashboardService < ApplicationService
    def self.call(teacher: nil)
      new(teacher: teacher).call
    end

    def initialize(teacher:)
      @teacher = teacher   # StaffMember
    end

    def call
      students = assigned_students_in_assessment
      cycles   = AssessmentCycle
                   .kept
                   .where(student_id: students.map(&:id))
                   .includes(:skills_assessment, :behavior_assessment, :preference_assessment)
                   .order(:created_at)
                   .index_by(&:student_id)

      cards = students.map { |s| build_card(s, cycles[s.id]) }

      ServiceResult.success(
        summary: build_summary(cards),
        students: cards,
        assessment_period: current_period(cycles.values)
      )
    end

    private

    def assigned_students_in_assessment
      Student
        .joins(:teacher_student_assignments)
        .where(teacher_student_assignments: { teacher_id: @teacher.id })
        .where(status: "in_assessment")
        .where(teacher_student_assignments: { discarded_at: nil })  # respect soft-delete on assignments
        .distinct
        .order(:first_name, :last_name)
    end

    def build_card(student, cycle)
      skills   = cycle&.skills_assessment
      behavior = cycle&.behavior_assessment
      pref     = cycle&.preference_assessment

      {
        student_id: student.id,
        name: [ student.first_name, student.middle_name, student.last_name ].compact.join(" "),
        age: age_from_dob(student.date_of_birth),
        program_type: student.program_type,
        therapy_group: student.therapy_group,
        ablls: {
          status: skills&.status || "not_started",
          progress_percent: skills&.progress_percent || 0
        },
        behavior: {
          status: behavior&.status || "not_started"
        },
        preference: {
          status: pref&.status || "not_started"
        },
        assessment_cycle_id: cycle&.id
      }
    end

    def build_summary(cards)
      total       = cards.size
      completed   = cards.count { |c| c[:ablls][:status] == "submitted" && c[:behavior][:status] == "submitted" }
      in_progress = cards.count { |c|
        [ c[:ablls][:status], c[:behavior][:status] ].any? { |s| %w[draft in_progress].include?(s) }
      }
      not_started = total - completed - in_progress

      {
        total_students: total,
        completed: completed,
        in_progress: in_progress,
        not_started: not_started
      }
    end

    def current_period(cycles)
      cycle = cycles.max_by { |c| c.started_on || c.created_at }
      return nil unless cycle&.started_on

      end_date = cycle.completed_on || (cycle.started_on + 6.weeks)
      {
        start: cycle.started_on.iso8601,
        end: end_date.iso8601,
        label: "#{cycle.started_on.strftime('%b %-d')} – #{end_date.strftime('%b %-d, %Y')}"
      }
    end

    def age_from_dob(dob)
      return nil unless dob
      now = Date.current
      now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
    end
  end
end
