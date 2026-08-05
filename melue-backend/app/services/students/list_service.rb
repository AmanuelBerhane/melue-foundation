# frozen_string_literal: true

module Students
  # Lists students with search, filtering, and pagination.
  # Teachers see only their assigned students; other roles see all.
  class ListService < ApplicationService
    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 100

    # @param current_user [User] the authenticated user
    # @param params [Hash] filter/pagination params (:q, :program_type, :therapy_group, :page, :per_page)
    def initialize(current_user:, params: {})
      @current_user = current_user
      @params = params
    end

    def call
      staff = staff_member
      return failure("Staff profile required") unless staff

      students = base_scope(staff)
      students = students.search_by_name(@params[:q])
      students = students.by_program_type(@params[:program_type])
      students = students.by_therapy_group(@params[:therapy_group])

      total_count = students.count
      page = [(@params[:page].to_i), 1].max
      raw_per_page = @params[:per_page].present? ? @params[:per_page].to_i : DEFAULT_PER_PAGE
      per_page = [[raw_per_page, 1].max, MAX_PER_PAGE].min

      paginated = students.order(:last_name, :first_name)
                          .offset((page - 1) * per_page)
                          .limit(per_page)

      success(
        students: paginated,
        meta: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil
        }
      )
    end

    private

    def staff_member
      @staff_member ||= StaffMember.find_by(user_id: @current_user.id)
    end

    def base_scope(staff)
      if staff.can_view_all_students?
        Student.all
      else
        # Teachers only see students they are assigned to
        Student.where(
          id: TeacherStudentAssignment.where(teacher_id: staff.id).select(:student_id)
        )
      end
    end
  end
end
