# frozen_string_literal: true

module Api
  module V1
    class AssessmentsController < Api::V1::BaseController
      before_action :require_staff_member!

      def dashboard
        result = ::Assessments::DashboardService.call(teacher: current_staff_member)

        if result.success?
          render json: result.data
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      def launch
        student = Student.find(params.require(:student_id))
        type    = params.require(:assessment_type).to_s

        unless assigned_to?(student)
          return render json: { error: "Not authorized for this student" }, status: :forbidden
        end

        cycle = AssessmentCycle.kept.find_or_create_by!(student: student, status: "in_progress") do |c|
          c.started_on = Date.current
        end

        assessment = cycle.find_or_build_assessment(type)
        if assessment.draft?
          assessment.status = "in_progress"
          assessment.started_at ||= Time.current
        end
        assessment.save!

        render json: {
          assessment_id: assessment.id,
          assessment_type: type,
          assessment_cycle_id: cycle.id,
          status: assessment.status
        }, status: :ok
      end

      private

      def assigned_to?(student)
        TeacherStudentAssignment
          .kept
          .exists?(teacher_id: current_staff_member.id, student_id: student.id)
      end
    end
  end
end
