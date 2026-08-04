class User < ApplicationRecord
  include Rodauth::Rails.model
  enum :status, { unverified: 1, verified: 2, closed: 3 }

  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  has_many :permissions, through: :roles

  def has_permission?(resource, action)
    permissions.exists?(resource: resource.to_s, action: action.to_s)
  end
end
