module Authorization
  extend ActiveSupport::Concern

  private

  # Canonical role-name resolver: accepts Role::Names constants, symbols,
  # or snake_case / titleized strings and returns the set of canonical names
  # that should be checked.
  ROLE_CANONICAL_MAP = {
    # Symbols / snake_case strings
    "teacher"              => [ Role::Names::TEACHER ],
    "therapist"            => [ Role::Names::TEACHER ],
    "therapy_coordinator"  => [ Role::Names::THERAPY_COORDINATOR ],
    "coordinator"          => [ Role::Names::THERAPY_COORDINATOR ],
    "clinical_staff"       => [ Role::Names::THERAPY_COORDINATOR ],
    "program_director"     => [ Role::Names::PROGRAM_DIRECTOR ],
    "director"             => [ Role::Names::DIRECTOR ],
    "institutional_admin"  => [ Role::Names::INSTITUTIONAL_ADMIN ],
    "system_admin"         => [ Role::Names::SYSTEM_ADMIN ],
    "sysadmin"             => [ Role::Names::SYSTEM_ADMIN ],
    "parent"               => [ Role::Names::PARENT ],
    # Canonical display names (already correct)
    Role::Names::TEACHER               => [ Role::Names::TEACHER ],
    Role::Names::THERAPY_COORDINATOR   => [ Role::Names::THERAPY_COORDINATOR ],
    Role::Names::PROGRAM_DIRECTOR      => [ Role::Names::PROGRAM_DIRECTOR ],
    Role::Names::DIRECTOR              => [ Role::Names::DIRECTOR ],
    Role::Names::INSTITUTIONAL_ADMIN   => [ Role::Names::INSTITUTIONAL_ADMIN ],
    Role::Names::SYSTEM_ADMIN          => [ Role::Names::SYSTEM_ADMIN ],
    Role::Names::PARENT                => [ Role::Names::PARENT ]
  }.freeze

  # Resolve any role identifier to its canonical Role::Names constant(s).
  def resolve_canonical_role(name)
    key = name.to_s.strip
    ROLE_CANONICAL_MAP[key] || ROLE_CANONICAL_MAP[key.downcase.tr(" ", "_")] || [ key ]
  end

  def require_role(role_name)
    return if current_user&.has_role?(role_name)

    role_display = role_name.to_s.titleize
    render json: { error: "Forbidden: #{role_display} access required" },
           status: :forbidden
  end

  def require_institutional_admin
    return if current_user&.has_any_role?(
      Role::Names::INSTITUTIONAL_ADMIN,
      Role::Names::SYSTEM_ADMIN
    )

    render json: { error: "Forbidden: Institutional Admin access required" }, status: :forbidden
  end

  def require_system_admin
    return if current_user&.has_any_role?(Role::Names::SYSTEM_ADMIN)

    render json: { error: "Forbidden: System Admin access required" }, status: :forbidden
  end

  def require_coordinator
    return if current_user&.has_any_role?(
      Role::Names::THERAPY_COORDINATOR,
      Role::Names::INSTITUTIONAL_ADMIN,
      Role::Names::SYSTEM_ADMIN
    )

    render json: { error: "Forbidden: Therapy Coordinator access required" },
           status: :forbidden
  end

  def require_program_director
    return if current_user&.has_any_role?(
      Role::Names::PROGRAM_DIRECTOR,
      Role::Names::DIRECTOR,
      Role::Names::INSTITUTIONAL_ADMIN,
      Role::Names::SYSTEM_ADMIN
    )

    render json: { error: "Forbidden: Program Director access required" },
           status: :forbidden
  end

  def current_user_has_role?(role_names)
    canonical = Array(role_names).flat_map { |n| resolve_canonical_role(n) }.uniq
    current_user.role_assignments.active.joins(:role).exists?(roles: { name: canonical })
  end

  def authorize_iup_management
    unless current_user_has_role?([
      Role::Names::PROGRAM_DIRECTOR,
      Role::Names::DIRECTOR,
      Role::Names::THERAPY_COORDINATOR
    ])
      render_error("Insufficient permissions for this action", :forbidden)
    end
  end
end
