class User < ApplicationRecord
  include Rodauth::Rails.model

  has_one :staff_member, dependent: :restrict_with_error

  enum :status, { unverified: 1, verified: 2, closed: 3 }

  validates :email, presence: true, uniqueness: { case_sensitive: false }
end

