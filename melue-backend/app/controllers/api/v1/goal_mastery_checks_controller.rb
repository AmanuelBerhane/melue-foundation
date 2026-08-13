# frozen_string_literal: true

class Api::V1::GoalMasteryChecksController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_staff_member!

  # POST /api/v1/student_goals/:student_goal_id/mastery_checks
  #
  # Initiates a goal mastery check by Teacher A (FR-100).
  # Marks the goal check as pending verification from Teacher B and Teacher C.
  #
  # @oas_include
  # @summary Initiate a goal mastery check
  # @tags Goal Mastery
  # @auth [bearer_jwt]
  # @response_ref (201) #/components/responses/Success
  # @response_ref (422) #/components/responses/Error
  def create
    student_goal = StudentGoal.find(params[:student_goal_id])

    if student_goal.goal_mastery_checks.where(status: [ "pending_verifications", "pending_approval" ]).exists?
      return render_error("Mastery check already in progress for this goal", :unprocessable_entity)
    end

    mastery_check = student_goal.goal_mastery_checks.build(
      initiating_teacher: current_staff_member,
      status: :pending_verifications
    )

    if mastery_check.save
      render json: { mastery_check: mastery_check }, status: :created
    else
      render_error(mastery_check.errors.full_messages, :unprocessable_entity)
    end
  end

  # GET /api/v1/mastery_checks/:id
  #
  # Returns the mastery check, verifications, and recent trials from Teacher A (FR-105b).
  #
  # @oas_include
  # @summary View goal history and verifications
  # @tags Goal Mastery
  # @auth [bearer_jwt]
  def show
    mastery_check = GoalMasteryCheck.includes(:goal_mastery_verifications).find(params[:id])

    # Normally we'd serialize this cleanly. We just return the JSON struct here.
    render json: {
      mastery_check: mastery_check,
      verifications: mastery_check.goal_mastery_verifications,
      trials: mastery_check.student_goal.trials.order(logged_at: :desc).limit(20) # recent trials
    }
  end

  # PATCH /api/v1/mastery_checks/:id/approve
  #
  # Program Director approves the mastery check (FR-105d).
  #
  # @oas_include
  # @summary Approve mastery check
  # @tags Goal Mastery
  # @auth [bearer_jwt]
  def approve
    mastery_check = GoalMasteryCheck.find(params[:id])

    if mastery_check.status != "pending_approval"
      return render_error("Only pending checks can be approved", :unprocessable_entity)
    end

    ActiveRecord::Base.transaction do
      mastery_check.update!(status: :approved, approving_director_id: current_staff_member.id)
      mastery_check.student_goal.update!(status: :mastered)

      # We would also notify the teachers and therapy coordinator here
      # Notifications::GoalMasteredNotifier.call(mastery_check)
    end

    render json: { message: "Goal approved and marked as mastered." }, status: :ok
  end

  # PATCH /api/v1/mastery_checks/:id/reject
  #
  # Program Director rejects the mastery check (FR-105c).
  #
  # @oas_include
  # @summary Reject mastery check
  # @tags Active Therapy
  # @auth [bearer_jwt]
  def reject
    mastery_check = GoalMasteryCheck.find(params[:id])

    if mastery_check.status != "pending_approval"
      return render_error("Only pending checks can be rejected", :unprocessable_entity)
    end

    ActiveRecord::Base.transaction do
      mastery_check.update!(status: :rejected, rejection_reason: params[:reason])
      mastery_check.student_goal.update!(status: :in_progress)

      # We would also notify Teacher A here
      # Notifications::GoalRejectedNotifier.call(mastery_check)
    end

    render json: { message: "Goal rejected and returned to in_progress." }, status: :ok
  end

  private

  def require_staff_member!
    render_error("Staff profile required", :forbidden) unless current_staff_member
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end
end
