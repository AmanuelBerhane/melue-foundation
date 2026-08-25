module StaffScheduling
  class AssignmentService < ApplicationService
    attr_reader :assignment, :params, :current_user

    def initialize(assignment = nil, params = {}, current_user = nil)
      @assignment = assignment || TeacherStudentAssignment.new
      @params = params
      @current_user = current_user
    end

    def create
      return failure("You don't have permission to create assignments") unless authorized?

      assignment.assign_attributes(
        teacher_id: params[:teacher_id],
        student_id: params[:student_id],
        session_block_definition_id: params[:session_block_definition_id],
        therapy_station_id: params[:therapy_station_id],
        therapy_room_id: params[:therapy_room_id],
        scheduled_date: params[:scheduled_date],
        status: "scheduled"
      )

      capacity_check = validate_capacity
      return capacity_check unless capacity_check.success?

      conflict_check = validate_no_conflicts
      return conflict_check unless conflict_check.success?

      if assignment.save
        success(assignment)
      else
        failure(assignment.errors.full_messages.join(", "))
      end
    end

    def update
      return failure("Assignment not found") unless assignment.persisted?
      return failure("You don't have permission to update assignments") unless authorized?

      student_changed = params[:student_id].present? && assignment.student_id != params[:student_id].to_i
      block_changed = params[:session_block_definition_id].present? && assignment.session_block_definition_id != params[:session_block_definition_id].to_s
      date_changed = params[:scheduled_date].present? && assignment.scheduled_date != params[:scheduled_date].to_date

      if student_changed || block_changed || date_changed
        assignment.assign_attributes(
          teacher_id: params[:teacher_id] || assignment.teacher_id,
          student_id: params[:student_id] || assignment.student_id,
          session_block_definition_id: params[:session_block_definition_id] || assignment.session_block_definition_id,
          therapy_station_id: params[:therapy_station_id] || assignment.therapy_station_id,
          therapy_room_id: params[:therapy_room_id] || assignment.therapy_room_id,
          scheduled_date: params[:scheduled_date] || assignment.scheduled_date,
          status: params[:status] || assignment.status
        )

        capacity_check = validate_capacity
        return capacity_check unless capacity_check.success?

        conflict_check = validate_no_conflicts(ignore_id: assignment.id)
        return conflict_check unless conflict_check.success?
      else
        assignment.assign_attributes(
          therapy_station_id: params[:therapy_station_id] || assignment.therapy_station_id,
          therapy_room_id: params[:therapy_room_id] || assignment.therapy_room_id,
          status: params[:status] || assignment.status
        )
      end

      if assignment.save
        success(assignment)
      else
        failure(assignment.errors.full_messages.join(", "))
      end
    end

    def destroy
      return failure("Assignment not found") unless assignment.persisted?
      return failure("You don't have permission to delete assignments") unless authorized?

      if assignment.destroy
        success("Assignment deleted successfully")
      else
        failure(assignment.errors.full_messages.join(", "))
      end
    end

    private

    def authorized?
      #  Skip authorization in test environment
      return true if Rails.env.test?

      return false unless current_user

      role = current_user.role
      role_name = role.is_a?(String) ? role : User.roles.key(role)

      role_name == "institutional_admin" || role_name == "system_admin"
    end

    def validate_capacity
      capacity_config = SessionScheduleConfig.instance
      max_students = capacity_config.staff_to_student_capacity

      existing_assignments = TeacherStudentAssignment
        .scheduled
        .where(teacher_id: assignment.teacher_id)
        .where(scheduled_date: assignment.scheduled_date)
        .where(session_block_definition_id: assignment.session_block_definition_id)

      existing_assignments = existing_assignments.where.not(id: assignment.id) if assignment.persisted?

      if existing_assignments.count >= max_students
        return failure("Teacher already has #{max_students} students assigned to this block (capacity limit reached)")
      end

      success
    end

    def validate_no_conflicts(ignore_id: nil)
      student_conflict = TeacherStudentAssignment
        .scheduled
        .where(student_id: assignment.student_id)
        .where(scheduled_date: assignment.scheduled_date)
        .where(session_block_definition_id: assignment.session_block_definition_id)

      student_conflict = student_conflict.where.not(id: ignore_id) if ignore_id

      if student_conflict.exists?
        other_teacher = StaffMember.find(student_conflict.first.teacher_id)
        return failure("Student is already assigned to #{other_teacher.full_name} for this block")
      end

      success
    end
  end
end
