# frozen_string_literal: true

module TherapyCoordinator
  # SCR-TC-002 — Live Session Monitoring.
  # Snapshot of every in-progress therapy session: teacher, station, room and
  # block timing, each participant with their assigned goals, and the live
  # trial counts logged so far in that session. Clients poll this endpoint
  # (SRS §5: polling for MVP, WebSockets post-MVP).
  class ActiveSessionsService < ApplicationService
    INDEPENDENT_PROMPT_LABEL = "+"

    def initialize(filters = {})
      @filters = filters
    end

    def call
      sessions = load_sessions
      session_ids = sessions.map(&:id)
      @trial_stats = trial_stats_for(session_ids)
      @last_trials = last_trials_for(session_ids)
      @incident_counts = BehaviorIncident.where(therapy_session_id: session_ids).group(:therapy_session_id).count
      @goals_by_student = goals_for(sessions)

      serialized = sessions.map { |session| serialize_session(session) }

      success({
        generated_at: Time.current.iso8601,
        summary: {
          active_sessions: serialized.size,
          students_in_session: serialized.sum { |s| s[:participants].size },
          rooms_in_use: sessions.map(&:therapy_room_id).uniq.size,
          trials_logged: serialized.sum { |s| s[:trials_logged] }
        },
        sessions: serialized
      })
    end

    private

    def load_sessions
      scope = TherapySession.kept.in_progress
                            .includes(:teacher, :therapy_station, :therapy_room, :session_block_definition,
                                      session_participants: :student)
                            .order(:started_at)
      scope = scope.where(therapy_station_id: @filters[:station_id]) if @filters[:station_id].present?
      scope = scope.where(therapy_room_id: @filters[:room_id]) if @filters[:room_id].present?
      scope = scope.where(teacher_id: @filters[:teacher_id]) if @filters[:teacher_id].present?
      scope.to_a
    end

    # { [participant_id, student_goal_id] => { "correct" => n, ..., independent: n } }
    def trial_stats_for(session_ids)
      stats = Hash.new { |h, k| h[k] = Hash.new(0) }
      Trial.kept.where(therapy_session_id: session_ids)
           .group(:session_participant_id, :student_goal_id, :outcome, :prompt_label_snapshot)
           .count
           .each do |(participant_id, goal_id, outcome, label), count|
             bucket = stats[[ participant_id, goal_id ]]
             bucket[outcome] += count
             bucket[:independent] += count if outcome == "correct" && label == INDEPENDENT_PROMPT_LABEL
           end
      stats
    end

    # Latest trial per (participant, goal), used for "last prompt" and activity time.
    def last_trials_for(session_ids)
      Trial.kept.where(therapy_session_id: session_ids)
           .select("DISTINCT ON (session_participant_id, student_goal_id) trials.*")
           .order(:session_participant_id, :student_goal_id, logged_at: :desc, id: :desc)
           .index_by { |t| [ t.session_participant_id, t.student_goal_id ] }
    end

    def goals_for(sessions)
      student_ids = sessions.flat_map { |s| s.session_participants.map(&:student_id) }.uniq
      StudentGoal.kept.active_or_in_progress
                 .includes(:goal)
                 .where(student_id: student_ids)
                 .order(:created_at)
                 .group_by(&:student_id)
    end

    def serialize_session(session)
      block = session.session_block_definition
      participants = session.session_participants.reject(&:discarded?).sort_by { |p| p.card_position_active? ? 0 : 1 }
      serialized_participants = participants.map { |p| serialize_participant(p, session) }

      {
        id: session.id,
        status: session.status,
        started_at: session.started_at&.iso8601,
        elapsed_seconds: session.started_at ? (Time.current - session.started_at).to_i : 0,
        block: {
          id: block.id,
          name: block.name,
          round: block.round,
          start_time: block.start_time.strftime("%H:%M"),
          end_time: block.end_time.strftime("%H:%M"),
          seconds_remaining: block.seconds_remaining
        },
        teacher: { id: session.teacher.id, full_name: session.teacher.full_name },
        station: { id: session.therapy_station.id, name: session.therapy_station.name },
        room: { id: session.therapy_room.id, name: session.therapy_room.name },
        participants: serialized_participants,
        trials_logged: serialized_participants.sum { |p| p[:trials_logged] },
        incidents_count: @incident_counts[session.id] || 0,
        last_activity_at: serialized_participants.filter_map { |p| p[:last_trial_at] }.max
      }
    end

    def serialize_participant(participant, session)
      student = participant.student
      goals = assigned_goals(participant, session)
      serialized_goals = goals.map { |goal| serialize_goal(goal, participant) }

      {
        id: participant.id,
        card_position: participant.card_position,
        student: { id: student.id, full_name: student.full_name, therapy_group: student.therapy_group },
        current_focus_goal_id: participant.current_focus_student_goal_id,
        goals: serialized_goals,
        trials_logged: serialized_goals.sum { |g| g[:trials][:total] },
        last_trial_at: serialized_goals.filter_map { |g| g[:last_trial_at] }.max
      }
    end

    # Goals assigned at this session's station, plus the current focus goal
    # even if it belongs to another station.
    def assigned_goals(participant, session)
      student_goals = @goals_by_student[participant.student_id] || []
      student_goals.select do |goal|
        goal.therapy_station_id == session.therapy_station_id ||
          goal.id == participant.current_focus_student_goal_id
      end
    end

    def serialize_goal(student_goal, participant)
      key = [ participant.id, student_goal.id ]
      stats = @trial_stats.fetch(key, {})
      correct = stats["correct"] || 0
      incorrect = stats["incorrect"] || 0
      no_response = stats["no_response"] || 0
      total = correct + incorrect + no_response
      last_trial = @last_trials[key]

      {
        student_goal_id: student_goal.id,
        goal_name: student_goal.goal_name,
        goal_type: student_goal.goal_type,
        status: student_goal.status,
        progress_percent: student_goal.progress_percent.to_f,
        is_current_focus: student_goal.id == participant.current_focus_student_goal_id,
        trials: {
          total: total,
          correct: correct,
          incorrect: incorrect,
          no_response: no_response,
          independence_percent: total.zero? ? 0.0 : ((stats[:independent].to_f / total) * 100).round(1)
        },
        last_prompt: last_trial&.prompt_label_snapshot,
        last_outcome: last_trial&.outcome,
        last_trial_at: last_trial&.logged_at&.iso8601
      }
    end
  end
end
