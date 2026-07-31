# frozen_string_literal: true

class Api::V1::TherapySessionsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :require_staff_member!
  before_action :set_session, only: %i[show dashboard update_active_goal]

  # GET /api/v1/today/session
  #
  # Returns the teacher's current dated assignment context, including:
  # block info, countdown timer, both student cards with goal pills,
  # active prompt levels, and current session state (FR-088, FR-089).
  #
  # @oas_include
  # @summary Get today's session dashboard context
  # @tags Active Therapy
  # @auth [bearer_jwt]
  # @response_ref (200) #/components/responses/TodaySessionContext
  # @response_ref (404) #/components/responses/Error
  def today_session
    assignment = todays_assignment
    return render_not_found("No scheduled assignment found for today") unless assignment

    active_session = current_staff_member.active_session

    render json: {
      assignment: assignment_context(assignment),
      session: active_session ? session_context(active_session) : nil,
      prompt_levels: PromptLevel.active.map { |p| prompt_level_payload(p) }
    }
  end

  # POST /api/v1/therapy_sessions/start
  #
  # Starts a new therapy session from a scheduled assignment.
  # Idempotent — returns the existing session if already started (FR-088).
  #
  # @oas_include
  # @summary Start a therapy session
  # @tags Active Therapy
  # @auth [bearer_jwt]
  # @request_body_ref #/components/requestBodies/StartSession
  # @response_ref (201) #/components/responses/SessionStarted
  # @response_ref (422) #/components/responses/Error
  def start
    assignment = TeacherStudentAssignment.find_by(id: params[:assignment_id])
    return render_not_found("Assignment not found") unless assignment

    result = TherapySessions::StartService.call(
      assignment: assignment,
      staff_member: current_staff_member
    )

    if result.success?
      render json: { session: session_context(result.data) }, status: :created
    else
      render_error(result.error, :unprocessable_entity)
    end
  end

  # GET /api/v1/therapy_sessions/:id
  #
  # Returns full session state with both student cards and goal pills (FR-090–FR-092).
  #
  # @oas_include
  # @summary Get therapy session
  # @tags Active Therapy
  # @auth [bearer_jwt]
  # @response_ref (200) #/components/responses/SessionDashboard
  # @response_ref (404) #/components/responses/Error
  def show
    render json: TherapySessionSerializer.new(@session).as_json
  end

  # GET /api/v1/therapy_sessions/:id/dashboard
  #
  # Full dashboard payload: station, room, block timer, student cards,
  # goal pills, recent trial streams, and prompt bar (FR-089–FR-094).
  #
  # @oas_include
  # @summary Get full session dashboard
  # @tags Active Therapy
  # @auth [bearer_jwt]
  # @response_ref (200) #/components/responses/SessionDashboard
  # @response_ref (404) #/components/responses/Error
  def dashboard
    render json: TherapySessionSerializer.new(@session).as_json
  end

  # PATCH /api/v1/therapy_sessions/:id/participants/:participant_id/active_goal
  #
  # Updates the current focus goal for a session participant (FR-092).
  # Only changes presentation state — does not alter the scheduled assignment.
  #
  # @oas_include
  # @summary Update active goal for a participant
  # @tags Active Therapy
  # @auth [bearer_jwt]
  # @request_body_ref #/components/requestBodies/UpdateActiveGoal
  # @response_ref (200) #/components/responses/ActiveGoalUpdated
  # @response_ref (422) #/components/responses/Error
  def update_active_goal
    participant = @session.session_participants.find_by(id: params[:participant_id])
    return render_not_found("Participant not found") unless participant

    goal = StudentGoal.find_by(
      id: params[:student_goal_id],
      student_id: participant.student_id,
      therapy_station_id: @session.therapy_station_id
    )
    return render_error("Goal not found for this participant at this station", :unprocessable_entity) unless goal

    if participant.update(current_focus_student_goal: goal)
      render json: {
        participant_id: participant.id,
        current_focus_student_goal_id: participant.current_focus_student_goal_id
      }
    else
      render_error(participant.errors.full_messages, :unprocessable_entity)
    end
  end

  private

  def set_session
    @session = TherapySession
                 .includes(:therapy_station, :therapy_room, :session_block_definition)
                 .find_by(id: params[:id] || params[:therapy_session_id])
    render_not_found("Session not found") unless @session
  end

  def require_staff_member!
    render_error("Staff profile required", :forbidden) unless current_staff_member
  end

  def current_staff_member
    @current_staff_member ||= StaffMember.find_by(user_id: current_user.id)
  end

  def todays_assignment
    TeacherStudentAssignment
      .scheduled
      .for_teacher(current_staff_member.id)
      .for_today
      .includes(:session_block_definition, :therapy_station, :therapy_room)
      .first
  end

  def render_not_found(message)
    render_error(message, :not_found)
  end

  # ── Payload helpers ──────────────────────────────────────────────────────────

  def assignment_context(assignment)
    {
      id: assignment.id,
      scheduled_date: assignment.scheduled_date,
      status: assignment.status,
      block: block_payload(assignment.session_block_definition),
      station: { id: assignment.therapy_station_id, name: assignment.therapy_station.name },
      room: { id: assignment.therapy_room_id, name: assignment.therapy_room.name }
    }
  end

  def session_context(session)
    {
      id: session.id,
      status: session.status,
      started_at: session.started_at,
      ended_at: session.ended_at
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

  def participant_dashboard_payload(participant)
    goals = participant.student.active_goals_for_station(@session.therapy_station_id)
                       .includes(:goal)

    {
      id: participant.id,
      card_position: participant.card_position,
      student: {
        id: participant.student.id,
        full_name: participant.student.full_name,
        therapy_group: participant.student.therapy_group
      },
      current_focus_student_goal_id: participant.current_focus_student_goal_id,
      goals: goals.map { |g| goal_pill_payload(g) },
      recent_trials: participant.recent_trials(limit: 10).map { |t| trial_payload(t) }
    }
  end

  def goal_pill_payload(student_goal)
    {
      id: student_goal.id,
      name: student_goal.goal.name,
      goal_type: student_goal.goal.goal_type,
      status: student_goal.status,
      progress_percent: student_goal.progress_percent
    }
  end

  def trial_payload(trial)
    {
      id: trial.id,
      outcome: trial.outcome,
      prompt_label: trial.prompt_label_snapshot,
      logged_at: trial.logged_at,
      client_event_id: trial.client_event_id
    }
  end

  def prompt_level_payload(prompt_level)
    {
      id: prompt_level.id,
      label: prompt_level.label,
      color: prompt_level.color,
      display_order: prompt_level.display_order
    }
  end
end
