# frozen_string_literal: true

class Api::V1::GoalMasteryVerificationsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_staff_member!
  before_action :set_mastery_check

  # POST /api/v1/mastery_checks/:mastery_check_id/verifications
  #
  # Submits a verification from Teacher B or Teacher C (FR-102, FR-103).
  # If two verifications exist, it routes the goal to the Program Director (FR-105).
  #
  # @oas_include
  # @summary Submit a goal mastery verification
  # @tags Goal Mastery
  # @auth [bearer_jwt]
  # @response_ref (201) #/components/responses/Success
  # @response_ref (422) #/components/responses/Error
  def create
    if @mastery_check.initiating_teacher_id == current_staff_member.id
      return render_error("You cannot verify your own mastery check", :forbidden)
    end

    if @mastery_check.goal_mastery_verifications.where(verifying_teacher_id: current_staff_member.id).exists?
      return render_error("You have already verified this mastery check", :unprocessable_entity)
    end

    if @mastery_check.goal_mastery_verifications.count >= 2
      return render_error("This mastery check already has the required number of verifications", :unprocessable_entity)
    end

    verification = @mastery_check.goal_mastery_verifications.build(
      verifying_teacher: current_staff_member,
      outcome: params[:outcome],
      prompt_used: params[:prompt_used],
      notes: params[:notes]
    )

    if verification.save
      check_and_upgrade_status
      render json: { verification: verification, mastery_check: @mastery_check.reload }, status: :created
    else
      render_error(verification.errors.full_messages, :unprocessable_entity)
    end
  end

  private

  def set_mastery_check
    @mastery_check = GoalMasteryCheck.find(params[:mastery_check_id])
  end

  def require_staff_member!
    render_error("Staff profile required", :forbidden) unless current_staff_member
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end

  def check_and_upgrade_status
    verifications = @mastery_check.goal_mastery_verifications

    # FR-104 & FR-105: Wait until there are exactly 2 verifications.
    if verifications.count == 2
      if verifications.all? { |v| v.outcome == "success" }
        @mastery_check.update!(status: :pending_approval)
        @mastery_check.student_goal.update!(status: :pending_approval)

        # Trigger the mailer notification (FR-105a)
        ProgramDirectorMailer.mastery_check_submitted(@mastery_check).deliver_later
      else
        # If any verification failed, we reject it back to the initiating teacher.
        @mastery_check.update!(status: :rejected, rejection_reason: "One or more verifications failed.")
        @mastery_check.student_goal.update!(status: :in_progress)
      end
    end
  end
end
