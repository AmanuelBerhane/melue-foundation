# frozen_string_literal: true

class Iup < ApplicationRecord
  include Discard::Model

  belongs_to :student
  belongs_to :assessment_cycle, optional: true
  belongs_to :created_by_user, class_name: "User", foreign_key: :created_by_user_id, optional: true
  belongs_to :finalized_by_user, class_name: "User", foreign_key: :finalized_by_user_id, optional: true

  has_one :form_submission, as: :submittable, dependent: :destroy
  has_many :student_goals
  has_many :iup_signatures, dependent: :destroy

  before_destroy :prevent_destroy_if_goals_exist

  enum :status, { draft: "draft", active: "active", archived: "archived" }, prefix: true

  validates :status, presence: true
  validates :student, presence: true
  validate :only_one_active_iup_per_student, if: :status_active?
  validate :only_one_draft_iup_per_student, if: :status_draft?, on: :create

  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }
  scope :archived, -> { where(status: "archived") }

  delegate :values, to: :form_submission, prefix: true, allow_nil: true

  def program_director_signature
    iup_signatures.find_by(signer_role: "program_director")
  end

  def guardian_signature
    iup_signatures.find_by(signer_role: "guardian")
  end

  def signatures_complete?
    program_director_signature.present? && guardian_signature.present?
  end

  private

  def only_one_active_iup_per_student
    existing = Iup.where(student_id: student_id, status: "active")
    existing = existing.where.not(id: id) if persisted?
    errors.add(:base, "student already has an active IUP") if existing.exists?
  end

  def only_one_draft_iup_per_student
    existing = Iup.where(student_id: student_id, status: "draft")
    errors.add(:base, "student already has a draft IUP") if existing.exists?
  end

  def prevent_destroy_if_goals_exist
    return unless student_goals.kept.exists?

    errors.add(:base, "Cannot delete IUP with associated student goals")
    throw(:abort)
  end
end
