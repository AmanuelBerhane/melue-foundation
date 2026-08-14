module Auditable
  extend ActiveSupport::Concern

  included do
    after_create :log_create
    after_update :log_update
    after_destroy :log_destroy
  end

  private

  def log_create
    AuditLog.create!(
      user_id: current_audit_user_id,
      action: "create",
      resource_type: self.class.name,
      resource_id: id.to_s,
      change_data: attributes
    )
  end

  def log_update
    AuditLog.create!(
      user_id: current_audit_user_id,
      action: "update",
      resource_type: self.class.name,
      resource_id: id.to_s,
      change_data: saved_changes
    )
  end

  def log_destroy
    AuditLog.create!(
      user_id: current_audit_user_id,
      action: "destroy",
      resource_type: self.class.name,
      resource_id: id.to_s,
      change_data: attributes
    )
  end

  def current_audit_user_id
    defined?(Current) && Current.respond_to?(:user) ? Current.user&.id : nil
  end
end
