class User < ApplicationRecord
  include Rodauth::Rails.model

  enum :status, { unverified: 1, verified: 2, closed: 3 }
  enum :role, {
    system_admin: 0,
    institutional_admin: 1,
    therapist: 2,
    clinical_staff: 3
  }

  def has_role?(role_name)
    role_sym = role_name.to_sym
    return false unless self.class.roles.key?(role_sym)
    role == role_sym.to_s
  end
  has_one :staff_member, dependent: :restrict_with_error

  enum :status, { unverified: 1, verified: 2, closed: 3 }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  has_many :role_assignments, dependent: :destroy
  has_many :roles, through: :role_assignments
  has_many :active_role_assignments, -> { active }, class_name: "RoleAssignment", inverse_of: :user
  has_one :staff_member, dependent: :restrict_with_error
  has_one :guardian, dependent: :restrict_with_error

  enum :status, { unverified: 1, verified: 2, closed: 3 }

  # Returns the user's currently active roles.
  def active_roles
    roles.where(role_assignments: { revoked_at: nil })
  end

  # Assign a role to the user (idempotent for active assignments).
  def assign_role(role_name_or_record)
    role = role_name_or_record.is_a?(Role) ? role_name_or_record : Role.find_by!(name: role_name_or_record)
    return if role_assignments.active.exists?(role: role)

    role_assignments.create!(role: role)
  end

  # Returns true if the user holds the given role (active assignment).
  def has_role?(role_name_or_record)
    role_name = role_name_or_record.is_a?(Role) ? role_name_or_record.name : role_name_or_record
    active_roles.exists?(name: role_name)
  end

  # Returns the primary role used for post-login routing (FR-006).
  def primary_role
    active_roles.first
  end

  # Returns the home route for post-login redirect based on the user's role.
  def home_route
    primary_role&.home_route || "/"
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
end
