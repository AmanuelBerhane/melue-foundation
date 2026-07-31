# frozen_string_literal: true

# Serializes a TherapySession for the dashboard (FR-088–FR-094).
# Includes station, room, block timer, both participant cards, and prompt bar.
class TherapySessionSerializer < ApplicationSerializer
  private

  def serialize(session)
    {
      id: session.id,
      status: session.status,
      started_at: session.started_at,
      ended_at: session.ended_at,
      station: station_payload(session.therapy_station),
      room: room_payload(session.therapy_room),
      block: block_payload(session.session_block_definition),
      participants: participants_payload(session),
      prompt_levels: PromptLevelSerializer.new(PromptLevel.active).as_json
    }
  end

  def station_payload(station)
    {
      id: station.id,
      name: station.name
    }
  end

  def room_payload(room)
    {
      id: room.id,
      name: room.name
    }
  end

  def block_payload(block)
    {
      id: block.id,
      name: block.name,
      start_time: block.start_time.strftime("%H:%M"),
      end_time: block.end_time.strftime("%H:%M"),
      seconds_remaining: block.seconds_remaining
    }
  end

  def participants_payload(session)
    # Ordered so active card always comes first, secondary second
    session.session_participants
           .includes(:student, :current_focus_student_goal, :trials)
           .sort_by { |p| p.card_position_active? ? 0 : 1 }
           .map { |p| SessionParticipantSerializer.new(p).as_json }
  end
end
