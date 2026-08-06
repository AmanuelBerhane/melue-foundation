class Role < ApplicationRecord
  has_many :user_roles, dependent: :restrict_with_error
  has_many :users, through: :user_roles
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions

  validates :name, presence: true, uniqueness: true

  before_destroy :prevent_deletion_if_system_critical
  before_destroy :prevent_deletion_if_in_use

  private

  def prevent_deletion_if_system_critical
    if is_system_critical?
      errors.add(:base, "System critical roles cannot be deleted")
      throw(:abort)
    end
  end

  def prevent_deletion_if_in_use
    if users.exists?
      errors.add(:base, "Cannot delete role while it is assigned to users")
      throw(:abort)
    end
  end
end
