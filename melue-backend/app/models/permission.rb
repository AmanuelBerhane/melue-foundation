class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :roles, through: :role_permissions

  validates :resource, presence: true
  validates :action, presence: true
  validates :action, uniqueness: { scope: :resource, message: "should be unique per resource" }

  CANONICAL_RESOURCES = %w[
    students enrollments forms
    assessments skills_assessments behavior_assessments preference_assessments
    iups goals goal_domains prompt_levels
    sessions trials session_summaries
    behavior_incidents abc_lists
    staff_members staff_scheduling session_block_definitions session_schedule_configs
    reports oversight audit_logs
    parent_communications home_observations
    roles clinical_configs form_configurations
  ].freeze

  CANONICAL_ACTIONS = %w[view create edit delete approve index show update destroy manage].freeze

  def self.ensure_catalog_exists!
    %w[students assessments iups sessions behavior_incidents staff reports parent_portal admin].each do |res|
      %w[view create edit delete approve].each do |act|
        find_or_create_by!(resource: res, action: act)
      end
    end
  end
end
