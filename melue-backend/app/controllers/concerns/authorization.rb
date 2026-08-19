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
    require_role(:institutional_admin)
  end

  def require_system_admin
    require_role(:system_admin)
  end

  def require_coordinator
    return if current_user&.has_role?(:clinical_staff) ||
              current_user&.has_role?(:institutional_admin) ||
              current_user&.has_role?(:system_admin)

    render json: { error: "Forbidden: Therapy Coordinator access required" },
           status: :forbidden
  end
end
