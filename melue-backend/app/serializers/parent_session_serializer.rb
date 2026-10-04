# frozen_string_literal: true

# A finalised therapy session as seen by a guardian: when and where it ran,
# who ran it and how the child did on each goal. Scoped to one student.
class ParentSessionSerializer < ApplicationSerializer
  def initialize(resource, student:)
    super(resource)
    @student = student
  end

  private

  def serialize(session)
    block = session.session_block_definition

    {
      id: session.id,
      date: (session.started_at || session.created_at).to_date.iso8601,
      started_at: session.started_at&.iso8601,
      ended_at: session.ended_at&.iso8601,
      block: { name: block.name, start_time: block.start_time.strftime("%H:%M"), end_time: block.end_time.strftime("%H:%M") },
      station: session.therapy_station.name,
      room: session.therapy_room.name,
      teacher_name: session.teacher.full_name,
      summary_status: session.session_summary&.status,
      goals: goal_breakdown(session)
    }
  end

  def goal_breakdown(session)
    session.trials.select { |t| t.discarded_at.nil? && t.student_goal.student_id == @student.id }
           .group_by(&:student_goal)
           .map do |student_goal, trials|
             counts = trials.map(&:outcome).tally
             {
               student_goal_id: student_goal.id,
               goal_name: student_goal.goal_name,
               total: trials.size,
               correct: counts["correct"] || 0,
               incorrect: counts["incorrect"] || 0,
               no_response: counts["no_response"] || 0
             }
           end
  end
end
