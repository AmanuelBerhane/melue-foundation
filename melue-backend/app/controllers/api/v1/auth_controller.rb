# frozen_string_literal: true

class Api::V1::AuthController < Api::V1::BaseController
  before_action :authenticate_user!, only: [ :me ]

  # Normalize a canonical Role::Names value to the snake_case key the front-end expects.
  ROLE_DISPLAY_MAP = {
    Role::Names::TEACHER              => "teacher",
    Role::Names::THERAPIST            => "therapist",
    Role::Names::THERAPY_COORDINATOR  => "coordinator",
    Role::Names::PROGRAM_DIRECTOR     => "program_director",
    Role::Names::DIRECTOR             => "director",
    Role::Names::INSTITUTIONAL_ADMIN  => "institutional_admin",
    Role::Names::SYSTEM_ADMIN         => "system_admin",
    Role::Names::PARENT               => "parent"
  }.freeze

  def me
    roles = current_user.role_names.map { |n| ROLE_DISPLAY_MAP[n] || n.downcase.tr(" ", "_") }.uniq

    # Ensure at least one role is present for backwards compat
    roles = [ "teacher" ] if roles.empty?

    name = current_staff_member&.full_name ||
           current_user.guardian&.full_name ||
           current_user.email.split("@").first.titleize

    render json: {
      id: current_user.id.to_s,
      name: name,
      email: current_user.email,
      role: roles.first,
      roles: roles,
      modules: current_user.permitted_modules,
      permissions: current_user.permissions_list
    }
  end
end
