# frozen_string_literal: true

class Api::V1::AuthController < Api::V1::BaseController
  before_action :authenticate_user!, only: [ :me ]

  def me
    role_name = current_user.primary_role&.name || current_user.role&.to_s || "Teacher"
    normalized_role = case role_name
    when Role::Names::TEACHER, "teacher" then "teacher"
    when Role::Names::THERAPY_COORDINATOR, "coordinator" then "coordinator"
    when Role::Names::PROGRAM_DIRECTOR, "program_director" then "program_director"
    when Role::Names::DIRECTOR, "director" then "director"
    when Role::Names::INSTITUTIONAL_ADMIN, "institutional_admin" then "institutional_admin"
    when Role::Names::SYSTEM_ADMIN, "system_admin" then "system_admin"
    when Role::Names::PARENT, "parent" then "parent"
    else role_name.downcase.tr(" ", "_")
    end

    name = current_staff_member&.full_name ||
           current_user.guardian&.full_name ||
           current_user.email.split("@").first.titleize

    render json: {
      id: current_user.id.to_s,
      name: name,
      email: current_user.email,
      role: normalized_role
    }
  end
end
