# frozen_string_literal: true

class SessionSummary < ApplicationRecord
  belongs_to :therapy_session
  belongs_to :reviewed_by_user, class_name: "User", optional: true

  enum :status, { draft: "draft", submitted: "submitted", reviewed: "reviewed" }, prefix: true

  validates :therapy_session_id, presence: true, uniqueness: true
  validates :status, presence: true

  validate :reviewed_fields_consistency
  validate :submitted_fields_consistency

  scope :submitted_or_reviewed, -> { where(status: %w[submitted reviewed]) }

  private

  def reviewed_fields_consistency
    return unless status_reviewed?

    if reviewed_by_user_id.blank?
      errors.add(:reviewed_by_user_id, "must be present for reviewed summaries")
    end

    if reviewed_at.blank?
      errors.add(:reviewed_at, "must be present for reviewed summaries")
    end
  end

  def submitted_fields_consistency
    return unless status_submitted? || status_reviewed?

    if submitted_at.blank?
      errors.add(:submitted_at, "must be present for submitted/reviewed summaries")
    end
  end
end
