# frozen_string_literal: true

class Role < ApplicationRecord
  has_many :role_assignments, dependent: :restrict_with_error
  has_many :users, through: :role_assignments

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(is_active: true) }

  # Canonical system roles referenced throughout the application.
  module Names
    TEACHER = "Teacher"
    THERAPY_COORDINATOR = "Therapy Coordinator"
    PROGRAM_DIRECTOR = "Program Director"
    DIRECTOR = "Director"
    INSTITUTIONAL_ADMIN = "Institutional Administrator"
    SYSTEM_ADMIN = "System Administrator"
    PARENT = "Parent"
  end

  # Returns the home route for this role, used for post-login routing (FR-006).
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
end
