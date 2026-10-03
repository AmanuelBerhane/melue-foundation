# frozen_string_literal: true

class ParentCommunicationSerializer < ApplicationSerializer
  private

  def serialize(message)
    {
      id: message.id,
      student_id: message.student_id,
      guardian_id: message.guardian_id,
      sender_id: message.sender_user_id,
      sender_name: sender_name(message),
      direction: message.direction,
      kind: message.kind,
      content: message.content,
      sent_at: message.sent_at.iso8601,
      read_at: message.read_at&.iso8601
    }
  end

  def sender_name(message)
    user = message.sender_user
    user.staff_member&.full_name || user.guardian&.full_name || user.email
  end
end
