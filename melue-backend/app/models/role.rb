# frozen_string_literal: true

class Role < ApplicationRecord
  # Association updated to match main's 'role_assignments' naming
  has_many :role_assignments, dependent: :restrict_with_error
  has_many :users, through: :role_assignments

  # Retained from PR branch: Permission mapping
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions

  validates :name, presence: true, uniqueness: true

  # Retained from main: Active scope
  scope :active, -> { where(is_active: true) }

  # Retained from PR branch: Deletion protection callbacks
  before_destroy :prevent_deletion_if_system_critical
  before_destroy :prevent_deletion_if_in_use

  # Retained from main: Canonical role name constants
  module Names
    TEACHER = "Teacher"
    THERAPY_COORDINATOR = "Therapy Coordinator"
    PROGRAM_DIRECTOR = "Program Director"
    DIRECTOR = "Director"
    INSTITUTIONAL_ADMIN = "Institutional Administrator"
    SYSTEM_ADMIN = "System Administrator"
    PARENT = "Parent"
  end

  # Retained from main: Dynamic home route for post-login redirection
  def home_route
    case name
    when Names::TEACHER then "/teacher/dashboard"
    when Names::THERAPY_COORDINATOR then "/coordinator/dashboard"
    when Names::PROGRAM_DIRECTOR then "/program-director/dashboard"
    when Names::DIRECTOR then "/director/dashboard"
    when Names::INSTITUTIONAL_ADMIN, Names::SYSTEM_ADMIN then "/admin"
    when Names::PARENT then "/parent/dashboard"
    else "/"
    end
  end

  private

  # Retained from PR branch
  def prevent_deletion_if_system_critical
    if is_system_critical?
      errors.add(:base, "System critical roles cannot be deleted")
      throw(:abort)
    end
  end

  # Retained from PR branch
  def prevent_deletion_if_in_use
    if users.exists?
      errors.add(:base, "Cannot delete role while it is assigned to users")
      throw(:abort)
    end
  end
end
