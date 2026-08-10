# frozen_string_literal: true

module Students
  # Returns a full student profile including calculated age, guardian info,
  # headshot URL, and current goals summary (up to 2 goals per station).
  class ProfileService < ApplicationService
    # @param student_id [String] UUID of the student
    # @param current_user [User] the authenticated user
    def initialize(student_id:, current_user:)
      @student_id = student_id
      @current_user = current_user
    end

    def call
      staff = staff_member
      return failure("Staff profile required") unless staff

      student = find_student(staff)
      return failure("Student not found") unless student

      success(build_profile(student))
    end

    private

    def staff_member
      @staff_member ||= StaffMember.find_by(user_id: @current_user.id)
    end

    def find_student(staff)
      scope = if staff.can_view_all_students?
        Student.all
      else
        Student.where(
          id: TeacherStudentAssignment.where(teacher_id: staff.id).select(:student_id)
        )
      end

      scope.find_by(id: @student_id)
    end

    def build_profile(student)
      {
        id: student.id,
        full_name: student.full_name,
        first_name: student.first_name,
        middle_name: student.middle_name,
        last_name: student.last_name,
        date_of_birth: student.date_of_birth,
        age: student.age,
        program_type: student.program_type,
        therapy_group: student.therapy_group,
        status: student.status,
        diagnosis: student.diagnosis,
        guardian_name: student.guardian_name,
        guardian_phone: student.guardian_phone,
        headshot_url: headshot_url(student),
        current_goals_summary: student.current_goals_summary
      }
    end

    def headshot_url(student)
      return nil unless student.headshot.attached?

      Rails.application.routes.url_helpers.rails_blob_url(
        student.headshot,
        only_path: true
      )
    end
  end
end
