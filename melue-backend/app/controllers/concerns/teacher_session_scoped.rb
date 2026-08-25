# frozen_string_literal: true

module TeacherSessionScoped
  extend ActiveSupport::Concern

  private

  def set_session
    @session = TherapySession.find_by(id: params[:therapy_session_id])
    render_not_found("Session not found") unless @session
  end

  def authorize_teacher_session!
    unless @session.teacher_id == current_staff_member.id
      render_error("Forbidden: You are not the assigned teacher for this session", :forbidden)
    end
  end
end
