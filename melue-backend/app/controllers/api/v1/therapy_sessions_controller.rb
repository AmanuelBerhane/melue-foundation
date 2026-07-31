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
  # @response Today's session context (200) [Hash{ session: Hash, block: Hash, prompt_levels: Array }]
  # @response No scheduled assignment today (404) [Hash{ message: String }]
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
  # @request_body Assignment ID to start session from [!Hash{ assignment_id: String }]
  # @response Session started (201) [Hash{ session: Hash }]
  # @response Validation error (422) [Hash{ message: String }]
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
      render json: { message: result.error }, status: :unprocessable_entity
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
  # @parameter id(path) [!String] Therapy session UUID
  # @response Session details (200) [Hash]
  # @response Not found (404) [Hash{ message: String }]
  def show
    render json: { session: session_context(@session) }
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
  # @parameter id(path) [!String] Therapy session UUID
  # @response Dashboard payload (200) [Hash]
  def dashboard
    participants = @session.session_participants
                           .includes(
                             :student,
                             :teacher_student_assignment,
                             current_focus_student_goal: :goal,
                             trials: :prompt_level
                           )

    render json: {
      session: {
        id: @session.id,
        status: @session.status,
        started_at: @session.started_at,
        station: { id: @session.therapy_station_id, name: @session.therapy_station.name },
        room: { id: @session.therapy_room_id, name: @session.therapy_room.name },
        block: block_payload(@session.session_block_definition)
      },
      participants: participants.map { |p| participant_dashboard_payload(p) },
      prompt_levels: PromptLevel.active.map { |p| prompt_level_payload(p) }
    }
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
  # @parameter id(path) [!String] Therapy session UUID
  # @parameter participant_id(path) [!String] SessionParticipant UUID
  # @request_body Goal to focus on [!Hash{ student_goal_id: String }]
  # @response Updated participant (200) [Hash]
  # @response Validation error (422) [Hash{ message: String }]
  def update_active_goal
    participant = @session.session_participants.find_by(id: params[:participant_id])
    return render_not_found("Participant not found") unless participant

    goal = StudentGoal.find_by(
      id: params[:student_goal_id],
      student_id: participant.student_id,
      therapy_station_id: @session.therapy_station_id
    )
    return render json: { message: "Goal not found for this participant at this station" }, status: :unprocessable_entity unless goal

    if participant.update(current_focus_student_goal: goal)
      render json: {
        participant_id: participant.id,
        current_focus_student_goal_id: participant.current_focus_student_goal_id
      }
    else
      render json: { message: participant.errors.full_messages.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  def set_session
    @session = TherapySession
                 .includes(:therapy_station, :therapy_room, :session_block_definition)
                 .find_by(id: params[:id])
    render_not_found("Session not found") unless @session
  end

  def require_staff_member!
    render json: { message: "Staff profile required" }, status: :forbidden unless current_staff_member
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
    render json: { message: message }, status: :not_found
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
