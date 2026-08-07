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
end
