# app/controllers/api/v1/goal_assignments_controller.rb
class Api::V1::GoalAssignmentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_program_director!
  before_action :set_student_goal, only: [ :replace, :destroy ]

  def create
    student = Student.find(params[:student_id])
    goal = Goal.find(params[:goal_id])

    # Check if goal is active
    unless goal.is_active
      return render json: { error: "Goal is not active" }, status: :unprocessable_content
    end

    station = TherapyStation.find(params[:station_id])
    iup = params[:iup_id].present? ? Iup.find(params[:iup_id]) : create_iup(student)

    # Check capacity
    if student.student_goals.where(therapy_station: station, status: "active").count >= 2
      return render json: { error: "Student already has 2 goals for this station" },
                    status: :unprocessable_content
    end

    student_goal = student.student_goals.create!(
      goal: goal,
      therapy_station: station,
      iup: iup,
      status: "active"
    )

    render json: student_goal, status: :created
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: "#{e.model} not found" }, status: :not_found
  rescue => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def replace
    # Check if student_goal is already archived
    if @student_goal.status == "archived"
      return render json: { error: "Goal is already archived" }, status: :unprocessable_content
    end

    new_goal = Goal.find(params[:new_goal_id])

    # Check if new_goal is active
    unless new_goal.is_active
      return render json: { error: "Goal is not active" }, status: :unprocessable_content
    end

    # Check if the student already has 2 active goals for this station
    active_goals_count = @student_goal.student.student_goals
                            .where(therapy_station: @student_goal.therapy_station, status: "active")
                            .where.not(id: @student_goal.id)
                            .count

    if active_goals_count >= 2
      return render json: { error: "Student already has 2 goals for this station" },
                    status: :unprocessable_content
    end

    # Archive the current goal - use update_column to skip validations
    @student_goal.update_column(:status, "archived")

    # Update clinical note separately if needed
    if @student_goal.respond_to?(:clinical_note=)
      note = [ @student_goal.clinical_note, "Replaced with goal #{new_goal.id} at #{Time.current}" ].compact.join("\n")
      @student_goal.update_column(:clinical_note, note)
    end

    # Create new goal assignment
    new_student_goal = @student_goal.student.student_goals.create!(
      goal: new_goal,
      therapy_station: @student_goal.therapy_station,
      iup: @student_goal.iup,
      status: "active"
    )

    render json: {
      archived_goal: @student_goal,
      new_goal: new_student_goal
    }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Goal not found" }, status: :not_found
  rescue => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def destroy
    # Check if already archived
    if @student_goal.status == "archived"
      return render json: { error: "Goal is already archived" },
                    status: :unprocessable_content
    end

    # Check confirmation - handle string "true" and boolean true
    confirmation = params[:confirmation]
    unless confirmation == true || confirmation == "true" || confirmation == "1"
      return render json: { error: "Confirmation required to remove goal" },
                    status: :unprocessable_content
    end

    # Archive the goal - use update_column to skip validations
    @student_goal.update_column(:status, "archived")

    # Update clinical note separately if needed
    if @student_goal.respond_to?(:clinical_note=)
      note = [ @student_goal.clinical_note, "Removed: #{params[:reason] || 'No reason provided'}" ].compact.join("\n")
      @student_goal.update_column(:clinical_note, note)
    end

    render json: {
      message: "Goal assignment successfully removed",
      student_goal_id: @student_goal.id
    }, status: :ok
  rescue => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def set_student_goal
    @student_goal = StudentGoal.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Student goal not found" }, status: :not_found
  end

  def create_iup(student)
    student.iups.create!(status: "active")
  end

  def require_program_director!
    unless current_staff_member&.role_program_director?
      render json: { error: "Unauthorized - Program Director access required" }, status: :forbidden
    end
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end
end
