# frozen_string_literal: true

class TherapySession < ApplicationRecord
  include Discard::Model

  belongs_to :teacher, class_name: "StaffMember"
  belongs_to :session_block_definition
  belongs_to :therapy_station
  belongs_to :therapy_room

  has_many :session_participants, dependent: :destroy
  has_many :students, through: :session_participants
  has_many :trials, dependent: :restrict_with_error
  has_many :behavior_incidents, dependent: :nullify
  has_one :session_summary, dependent: :destroy

  enum :status, { in_progress: "in_progress", completed: "completed" }, prefix: true

  validates :status, presence: true
  validates :teacher, presence: true
  validate :exactly_two_participants_on_completion

  scope :in_progress, -> { where(status: "in_progress") }

  # Returns the active participant (card_position: active)
  def active_participant
    session_participants.find_by(card_position: SessionParticipant.card_positions[:active])
  end

  # Returns the secondary participant (card_position: secondary)
  def secondary_participant
    session_participants.find_by(card_position: SessionParticipant.card_positions[:secondary])
  end

  private

  # Enforces the participant invariant when completing a session.
  # Creation-time enforcement is handled by TherapySessions::StartService.
  # A session represents one teacher/block/room occurrence with one or two SessionParticipant records (melue_domain_model.md §2).
  def exactly_two_participants_on_completion
    return unless status_completed?

    count = session_participants.loaded? ? session_participants.reject(&:marked_for_destruction?).size : session_participants.count
    unless count.between?(1, 2)
      errors.add(:base, "a session must have one or two participants")
    end
  end
end
