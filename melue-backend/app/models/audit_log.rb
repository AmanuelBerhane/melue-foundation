class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, presence: true
  validates :resource_type, presence: true
end
