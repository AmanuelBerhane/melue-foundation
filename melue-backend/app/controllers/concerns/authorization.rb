module Authorization
  extend ActiveSupport::Concern

  private

  def require_role(role_name)
    return if current_user&.has_role?(role_name)

    role_display = role_name.to_s.titleize
    render json: { error: "Forbidden: #{role_display} access required" },
           status: :forbidden
  end

  def require_institutional_admin
    return if current_user&.has_role?(:institutional_admin) ||
              current_user&.has_role?("institutional_admin") ||
              current_user&.has_role?(Role::Names::INSTITUTIONAL_ADMIN) ||
              current_user&.has_role?(:system_admin) ||
              current_user&.has_role?(Role::Names::SYSTEM_ADMIN)

    render json: { error: "Forbidden: Institutional Admin access required" }, status: :forbidden
  end

  def require_system_admin
    return if current_user&.has_role?(:system_admin) ||
              current_user&.has_role?("system_admin") ||
              current_user&.has_role?(Role::Names::SYSTEM_ADMIN)

    render json: { error: "Forbidden: System Admin access required" }, status: :forbidden
  end

  def require_coordinator
    return if current_user&.has_role?(:clinical_staff) ||
              current_user&.has_role?(:institutional_admin) ||
              current_user&.has_role?(:system_admin)

    render json: { error: "Forbidden: Therapy Coordinator access required" },
           status: :forbidden
  end

  def require_program_director
    return if current_user&.has_role?(Role::Names::PROGRAM_DIRECTOR) ||
              current_user&.has_role?(Role::Names::DIRECTOR) ||
              current_user&.has_role?(:institutional_admin) ||
              current_user&.has_role?(:system_admin) ||
              current_user&.has_role?("Program Director") ||
              current_user&.has_role?(:program_director) ||
              current_user&.staff_member&.role_program_director? ||
              current_user&.staff_member&.role_admin?

    render json: { error: "Forbidden: Program Director access required" },
           status: :forbidden
  end

  def current_user_has_role?(role_names)
    current_user.role_assignments.where(revoked_at: nil).joins(:role).exists?(
      roles: { name: role_names }
    )
  end

  def authorize_iup_management
    unless current_user_has_role?([ "Program Director", "Director", "Coordinator" ])
      render_error("Insufficient permissions for this action", :forbidden)
    end
  end
end
