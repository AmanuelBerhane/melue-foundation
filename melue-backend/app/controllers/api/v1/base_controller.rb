# frozen_string_literal: true

class Api::V1::BaseController < Api::BaseController
  private

  # Most v1 endpoints act on behalf of a staff member rather than a bare user
  # account, so the staff profile lookup and the 404 helper live here.
  def require_staff_member!
    render_error("Staff profile required", :forbidden) unless current_staff_member
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id) if current_user
  end

  def render_not_found(message)
    render_error(message, :not_found)
  end
end
