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
end

RSpec.configure do |config|
  config.include AuthorizationHelpers, type: :request
end
