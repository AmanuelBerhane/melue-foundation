# frozen_string_literal: true

module SessionSummaries
  # Builds the complete session summary payload (read model) from source records.
  # Returns ServiceResult.success(payload).
  class BuildPayloadService < ApplicationService
    def initialize(session:)
      @session_id = session.id
    end

    def call
      # Load session with eager-loaded associations to prevent N+1 queries
      session = TherapySession.includes(
        :therapy_station,
        :therapy_room,
        :session_block_definition,
        :teacher,
        :trials,
        session_participants: :student
      ).find(@session_id)

      summary = session.session_summary || session.create_session_summary!

      # Sort participants: active first, then secondary
      sorted_participants = session.session_participants.sort_by do |p|
        SessionParticipant.card_positions[p.card_position] || 0
      end

      # Group trials by participant to compute metrics in memory
      trials_by_participant = session.trials.group_by(&:session_participant_id)

      # Preload active goals for all participants to prevent N+1
      participant_student_ids = sorted_participants.map(&:student_id)
      active_goals_by_student = StudentGoal.includes(:goal).where(
        student_id: participant_student_ids,
        therapy_station_id: session.therapy_station_id,
        status: %w[active in_progress]
      ).group_by(&:student_id)

      participants_payload = sorted_participants.map do |participant|
        participant_trials = trials_by_participant[participant.id] || []

        # Find unique goals that either have trials in this session OR are active/in_progress for this station
        goals_with_trials = participant_trials.map(&:student_goal).compact.uniq
        active_station_goals = active_goals_by_student[participant.student_id] || []
        combined_goals = (goals_with_trials + active_station_goals).uniq(&:id)

        goals_payload = combined_goals.map do |student_goal|
          trials_for_goal = participant_trials.select { |t| t.student_goal_id == student_goal.id }
          total_trials = trials_for_goal.size

          # Count prompt labels from snapshots
          prompt_breakdown = Hash.new(0)
          trials_for_goal.each do |trial|
            label = trial.prompt_label_snapshot || "Unknown"
            prompt_breakdown[label] += 1
          end

          # Compute independence percentage:
          # percentage of trials where outcome is 'correct' and prompt_label_snapshot is '+'
          if total_trials.zero?
            independence_percentage = 0.0
          else
            independent_correct = trials_for_goal.count do |trial|
              trial.outcome == "correct" && trial.prompt_label_snapshot == "+"
            end
            independence_percentage = ((independent_correct.to_f / total_trials) * 100).round(2)
          end

          {
            id: student_goal.id,
            name: student_goal.goal_name,
            total_trials: total_trials,
            prompt_breakdown: prompt_breakdown,
            independence_percentage: independence_percentage
          }
        end

        {
          id: participant.id,
          card_position: participant.card_position,
          student: {
            id: participant.student.id,
            name: participant.student.full_name
          },
          goals: goals_payload
        }
      end

      # Calculate duration
      duration = calculate_duration_minutes(session)

      payload = {
        summary: {
          id: summary.id,
          status: summary.status,
          qualitative_notes: summary.qualitative_notes,
          submitted_at: summary.submitted_at,
          reviewed_at: summary.reviewed_at
        },
        session: {
          id: session.id,
          status: session.status,
          station: { id: session.therapy_station.id, name: session.therapy_station.name },
          room: { id: session.therapy_room.id, name: session.therapy_room.name },
          teacher: { id: session.teacher.id, name: session.teacher.full_name },
          block: {
            id: session.session_block_definition.id,
            name: session.session_block_definition.name,
            start_time: session.session_block_definition.start_time.strftime("%H:%M"),
            end_time: session.session_block_definition.end_time.strftime("%H:%M")
          },
          started_at: session.started_at,
          ended_at: session.ended_at,
          total_duration_minutes: duration
        },
        participants: participants_payload,
        behavior_incidents: []
      }

      success(payload)
    end

    private

    def calculate_duration_minutes(session)
      start_time = session.started_at
      return nil if start_time.blank?

      end_time = if session.ended_at.present?
                   session.ended_at
      else
                   # Use block end time on the day of started_at
                   block = session.session_block_definition
                   date = session.started_at.to_date
                   Time.zone.local(
                     date.year, date.month, date.day,
                     block.end_time.hour, block.end_time.min, block.end_time.sec
                   )
      end

      duration_minutes = ((end_time - start_time) / 60.0).round
      [ duration_minutes, 0 ].max
    end
  end
end
