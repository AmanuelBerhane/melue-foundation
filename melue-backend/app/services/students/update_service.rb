# frozen_string_literal: true

module Students
  # Updates an existing student record.
  # RBAC: Only Therapy Coordinators and Program Directors may edit.
  # If the updated age mismatches the therapy group, the update still succeeds
  # but a soft warning is included in the data payload.
  class UpdateService < ApplicationService
    AGE_RANGES = {
      "basic" => (3..12),
      "functional_living" => (13..19)
    }.freeze

    # @param student_id [String] UUID of the student
    # @param params [Hash] student attributes to update (including optional :headshot file)
    # @param current_user [User] the authenticated user
    def initialize(student_id:, params:, current_user:)
      @student_id = student_id
      @params = params
      @current_user = current_user
    end

    def call
      staff = staff_member
      return failure("Staff profile required") unless staff
      return failure("You do not have permission to edit students") unless staff.can_edit_students?

      student = Student.find_by(id: @student_id)
      return failure("Student not found") unless student

      student.assign_attributes(student_params)
      attach_headshot(student)

      if student.save
        warning = age_mismatch_warning(student)
        data = { student: student }
        data[:warning] = warning if warning

        success(data)
      else
        failure(student.errors.full_messages.join(", "))
      end
    end

    private

    def staff_member
      @staff_member ||= StaffMember.find_by(user_id: @current_user.id)
    end

    def student_params
      @params.slice(
        :first_name, :middle_name, :last_name,
        :date_of_birth, :program_type, :therapy_group,
        :diagnosis, :guardian_name, :guardian_phone
      )
    end

    def attach_headshot(student)
      student.headshot.attach(@params[:headshot]) if @params[:headshot].present?
    end

    def age_mismatch_warning(student)
      return nil unless student.date_of_birth.present? && student.therapy_group.present?

      age = student.age
      return nil unless age

      valid_range = AGE_RANGES[student.therapy_group]
      return nil unless valid_range

      unless valid_range.include?(age)
        group_label = student.therapy_group == "basic" ? "Basic Therapy (ages 3–12)" : "Functional Living Skills (ages 13–19)"
        return "Age #{age} does not match the expected range for #{group_label}"
      end

      nil
    end
  end
end
