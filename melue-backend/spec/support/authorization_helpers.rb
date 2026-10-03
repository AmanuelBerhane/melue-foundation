# frozen_string_literal: true

module AuthorizationHelpers
  def authenticated_headers_for_role(role)
    user = create(:user, role)
    authenticated_headers(user)
  end

  def institutional_admin_headers
    authenticated_headers_for_role(:institutional_admin)
  end

  def therapist_headers
    authenticated_headers_for_role(:therapist)
  end

  def system_admin_headers
    authenticated_headers_for_role(:system_admin)
  end

  def clinical_staff_headers
    authenticated_headers_for_role(:clinical_staff)
  end

  def program_director_headers
    user = create(:user)
    create(:staff_member, :program_director, user: user)
    authenticated_headers(user)
  end

  def teacher_headers
    user = create(:user, :therapist)
    create(:staff_member, user: user, role: "teacher")
    authenticated_headers(user)
  end

  # Staff "admin" records map to the Director role.
  def director_headers
    user = create(:user)
    create(:staff_member, :admin, user: user)
    authenticated_headers(user)
  end

  def therapy_coordinator_headers
    user = create(:user)
    create(:staff_member, :therapy_coordinator, user: user)
    authenticated_headers(user)
  end

  # Creates a guardian portal account; pass the guardian to link children to it.
  def create_parent_user(guardian_name: "Parent A")
    user = create(:user)
    user.assign_role(Role.find_or_create_by!(name: Role::Names::PARENT))
    create(:guardian, user: user, full_name: guardian_name)
  end
end

RSpec.configure do |config|
  config.include AuthorizationHelpers, type: :request
end
