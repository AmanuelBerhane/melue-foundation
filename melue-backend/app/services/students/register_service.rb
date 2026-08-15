# frozen_string_literal: true

module Students
  # Creates a new student with status "registered".
  # Validates that the student's age is appropriate for the selected therapy group:
  #   - Basic Therapy: ages 3–12
  #   - Functional Living Skills: ages 13–19
  class RegisterService < ApplicationService
    AGE_RANGES = {
      "basic" => (3..12),
      "functional_living" => (13..19)
    }.freeze

    # @param params [Hash] student attributes (including optional :headshot file)
    # @param current_user [User] the authenticated user
    def initialize(params:, current_user:)
      @params = params
      @current_user = current_user
    end

    def call
      staff = staff_member
      return failure("Staff profile required") unless staff

      student = Student.new(student_params)
      student.status = :registered

      age_error = validate_age_for_therapy_group(student)
      return failure(age_error) if age_error

      attach_headshot(student)

      if student.save
        success(student)
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

    def validate_age_for_therapy_group(student)
      return nil unless student.date_of_birth.present? && student.therapy_group.present?

      age = student.age
      return nil unless age

      valid_range = AGE_RANGES[student.therapy_group]
      return nil unless valid_range

      unless valid_range.include?(age)
        group_label = student.therapy_group == "basic" ? "Basic Therapy (ages 3–12)" : "Functional Living Skills (ages 13–19)"
        return "Age #{age} is not appropriate for #{group_label}"
      end

      nil
    end

    def attach_headshot(student)
      student.headshot.attach(@params[:headshot]) if @params[:headshot].present?
    end
  end
end
