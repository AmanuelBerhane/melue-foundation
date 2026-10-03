class User < ApplicationRecord
  include Rodauth::Rails.model

  has_many :role_assignments, dependent: :destroy
  has_many :roles, through: :role_assignments
  has_many :active_role_assignments, -> { active }, class_name: "RoleAssignment", inverse_of: :user

  has_many :user_roles, dependent: :destroy
  has_many :permission_roles, through: :user_roles, source: :role
  has_many :permissions, through: :permission_roles

  has_one :staff_member, dependent: :restrict_with_error
  has_one :guardian, dependent: :restrict_with_error

  enum :status, { unverified: 1, verified: 2, closed: 3 }
  enum :role, {
    system_admin: 0,
    institutional_admin: 1,
    therapist: 2,
    clinical_staff: 3
  }

  validates :email, presence: true, uniqueness: { case_sensitive: false }

  # Resolve has_permission? through active role_assignments → roles → permissions.
  # Falls back to the legacy user_roles path for backwards-compat.
  def has_permission?(resource, action)
    # Primary path: role_assignments (RBAC)
    return true if Permission.joins(role_permissions: { role: :role_assignments })
                              .where(role_assignments: { user_id: id, revoked_at: nil })
                              .exists?(resource: resource.to_s, action: action.to_s)

    # Legacy fallback: user_roles
    permissions.exists?(resource: resource.to_s, action: action.to_s)
  end

  # Returns the user's currently active roles.
  def active_roles
    roles.where(role_assignments: { revoked_at: nil })
  end

  # Returns canonical role name strings for all active roles.
  def role_names
    names = active_roles.pluck(:name) | staff_member_role_names
    return names if names.any?

    # Fall back to the legacy enum column when no role_assignments exist.
    derived = derived_role
    derived ? [ derived.name ] : []
  end

  # Assign a role to the user (idempotent for active assignments).
  def assign_role(role_name_or_record)
    role = role_name_or_record.is_a?(Role) ? role_name_or_record : Role.find_by!(name: role_name_or_record)
    return if role_assignments.active.exists?(role: role)

    role_assignments.create!(role: role)
  end

  # Returns true if the user holds the given role (active assignment, staff
  # record, or role enum).
  def has_role?(role_name_or_record)
    canonical = resolve_to_canonical_name(role_name_or_record)

    return true if staff_member_role_names.include?(canonical)
    return true if role.present? && legacy_enum_matches?(canonical)

    active_roles.exists?(name: canonical)
  end

  # Returns true if the user holds ANY of the given roles.
  def has_any_role?(*role_names)
    canonical_names = role_names.flatten.map { |n| resolve_to_canonical_name(n) }

    return true if canonical_names.any? { |c| staff_member_role_names.include?(c) }
    return true if role.present? && canonical_names.any? { |c| legacy_enum_matches?(c) }

    active_roles.where(name: canonical_names).exists?
  end

  # Returns the primary role used for post-login routing (FR-006).
  def primary_role
    active_roles.first || permission_roles.first || staff_member_role || derived_role
  end

  def derived_role
    case role&.to_sym
    when :system_admin then Role.find_by(name: Role::Names::SYSTEM_ADMIN)
    when :institutional_admin then Role.find_by(name: Role::Names::INSTITUTIONAL_ADMIN)
    when :therapist then Role.find_by(name: Role::Names::TEACHER)
    else nil
    end
  end

  # Returns the home route for post-login redirect based on the user's role.
  def home_route
    return primary_role.home_route if primary_role.present?

    case role&.to_sym
    when :system_admin, :institutional_admin then "/admin"
    when :therapist, :clinical_staff then "/teacher/dashboard"
    else "/"
    end
  end

  # Returns true if the user holds any staff role (non-Parent).
  def staff?
    primary_role && primary_role.name != Role::Names::PARENT
  end

  # Role-aware session timeout in seconds (NFR-015).
  # Staff sessions expire after 15 minutes; parent sessions after 30 minutes.
  def session_timeout_seconds
    parent? ? 30.minutes : 15.minutes
  end

  private

  def parent?
    has_role?(Role::Names::PARENT)
  end

  # Map a role identifier (symbol, string, Role record) to its canonical
  # Role::Names constant so that checks are consistent regardless of input format.
  LEGACY_ENUM_TO_CANONICAL = {
    "system_admin"        => Role::Names::SYSTEM_ADMIN,
    "institutional_admin" => Role::Names::INSTITUTIONAL_ADMIN,
    "therapist"           => Role::Names::TEACHER,
    "clinical_staff"      => Role::Names::THERAPY_COORDINATOR
  }.freeze

  ALIAS_TO_CANONICAL = {
    "teacher"              => Role::Names::TEACHER,
    "therapist"            => Role::Names::TEACHER,
    "therapy_coordinator"  => Role::Names::THERAPY_COORDINATOR,
    "coordinator"          => Role::Names::THERAPY_COORDINATOR,
    "clinical_staff"       => Role::Names::THERAPY_COORDINATOR,
    "program_director"     => Role::Names::PROGRAM_DIRECTOR,
    "director"             => Role::Names::DIRECTOR,
    "institutional_admin"  => Role::Names::INSTITUTIONAL_ADMIN,
    "system_admin"         => Role::Names::SYSTEM_ADMIN,
    "sysadmin"             => Role::Names::SYSTEM_ADMIN,
    "parent"               => Role::Names::PARENT
  }.freeze

  def resolve_to_canonical_name(role_name_or_record)
    name = role_name_or_record.is_a?(Role) ? role_name_or_record.name : role_name_or_record.to_s
    ALIAS_TO_CANONICAL[name] || ALIAS_TO_CANONICAL[name.downcase.tr(" ", "_")] || name
  end

  # Staff records carry their own role enum, which must also satisfy RBAC.
  STAFF_MEMBER_ROLE_TO_CANONICAL = {
    "teacher"             => Role::Names::TEACHER,
    "therapy_coordinator" => Role::Names::THERAPY_COORDINATOR,
    "program_director"    => Role::Names::PROGRAM_DIRECTOR,
    "admin"               => Role::Names::DIRECTOR
  }.freeze

  # Canonical role name(s) derived from the user's staff record.
  def staff_member_role_names
    canonical = STAFF_MEMBER_ROLE_TO_CANONICAL[staff_member&.role.to_s]
    canonical ? [ canonical ] : []
  end

  # The Role record matching the user's staff record, if any.
  def staff_member_role
    name = staff_member_role_names.first
    name && Role.find_by(name: name)
  end

  def legacy_enum_matches?(canonical_name)
    LEGACY_ENUM_TO_CANONICAL[role.to_s] == canonical_name
  end
end
