# frozen_string_literal: true

module Students
  # Aggregates student progress monitoring data (FR-134, SCR-DIR-006 / SCR-TC-004).
  # Compiles full clinical history: student profile, assessments (ABLLS, Preference, Sensory),
  # active & past goals with task analysis steps, mastery verifications, full session history
  # (paginated), trial performance with prompt level fading, and behavior incident trends.
  class ProgressMonitoringService < ApplicationService
    DEFAULT_PER_PAGE = 50

    def initialize(student_id:, current_user: nil, page: 1, per_page: DEFAULT_PER_PAGE)
      @student_id   = student_id
      @current_user = current_user
      @page         = [ page.to_i, 1 ].max
      @per_page     = [ [ per_page.to_i, 1 ].max, 200 ].min
    end

    def call
      student = Student.includes(:guardians).find_by(id: @student_id)

      return failure("Student not found", :not_found) unless student

      success({
        student:                  build_student_profile(student),
        assessment_summary:       build_assessment_summary(student),
        current_goals:            build_goals_summary(student),
        session_history:          build_session_history(student),
        trial_performance:        build_trial_performance(student),
        behavior_incident_trends: build_behavior_incident_trends(student),
        goal_progress_charts:     build_goal_progress_charts(student),
        internal_notes:           build_internal_notes(student)
      })
    rescue StandardError => e
      failure(e.message)
    end

    private

    # ─────────────────────────────────────────────────────────
    # Student profile
    # ─────────────────────────────────────────────────────────

    def build_student_profile(student)
      primary_guardian = student.student_guardians.find_by(is_primary_contact: true)&.guardian ||
                         student.guardians.first
      active_iup = student.iups.find_by(status: "active")

      {
        id:                     student.id,
        first_name:             student.first_name,
        middle_name:            student.middle_name,
        last_name:              student.last_name,
        full_name:              student.full_name,
        date_of_birth:          student.date_of_birth,
        age:                    student.age,
        age_warning:            student.age_warning_for_group?,
        diagnosis:              student.diagnosis,
        program_type:           student.program_type,
        therapy_group:          student.therapy_group,
        status:                 student.status,
        enrollment_date:        student.created_at.to_date,
        active_iup_id:          active_iup&.id,
        active_iup_finalized_on: active_iup&.finalized_on,
        guardian: {
          name:  student.guardian_name || primary_guardian&.full_name,
          phone: student.guardian_phone || primary_guardian&.phone,
          email: student.guardian_email
        }
      }
    end

    # ─────────────────────────────────────────────────────────
    # Assessment summary (all cycles, most-recent detail)
    # ─────────────────────────────────────────────────────────

    def build_assessment_summary(student)
      cycles      = AssessmentCycle.where(student_id: student.id).order(created_at: :desc)
      latest_cycle = cycles.first

      return { cycles_count: 0, latest_cycle: nil, ablls: nil, preference: nil, sensory: nil } unless latest_cycle

      ablls = latest_cycle.ablls_assessment
      ablls_data = if ablls
                     {
                       id:                    ablls.id,
                       status:                ablls.status,
                       progress_percentage:   ablls.try(:progress_percentage) || 0.0,
                       need_analysis_summary: ablls.need_analysis_summary,
                       total_responses:       ablls.ablls_responses.count,
                       mastered_count:        ablls.ablls_responses.where(score: 2).count,
                       emerging_count:        ablls.ablls_responses.where(score: 1).count,
                       not_demonstrated_count: ablls.ablls_responses.where(score: 0).count
                     }
      end

      pref      = latest_cycle.preference_assessment
      pref_data = if pref
                    observations = pref.preference_observations.includes(:preference_inventory_item)
                    ranked_items = observations
                      .select { |o| o.duration_seconds.to_i > 0 || o.frequency_count.to_i > 0 }
                      .sort_by { |o| -(o.duration_seconds.to_i * 2 + o.frequency_count.to_i * 3) }
                      .first(5)
                      .map.with_index(1) do |obs, idx|
                        {
                          rank:             idx,
                          item_name:        obs.preference_inventory_item&.name || obs.custom_item_name || "Item",
                          category:         obs.preference_inventory_item&.category || "General",
                          duration_seconds: obs.duration_seconds.to_i,
                          frequency_count:  obs.frequency_count.to_i
                        }
                      end

                    { id: pref.id, status: pref.status, top_preferences: ranked_items }
      end

      sensory_record = SensoryAssessment.where(student_id: student.id).order(created_at: :desc).first rescue nil
      sensory_data   = if sensory_record
                         records = sensory_record.sensory_assessment_records rescue []
                         {
                           id:                 sensory_record.id,
                           status:             sensory_record.status,
                           activities_assessed: records.count
                         }
      end

      {
        cycles_count: cycles.count,
        latest_cycle: {
          id:           latest_cycle.id,
          status:       latest_cycle.status,
          started_on:   latest_cycle.started_on,
          completed_on: latest_cycle.completed_on
        },
        all_cycles: cycles.map { |c| { id: c.id, status: c.status, started_on: c.started_on, completed_on: c.completed_on } },
        ablls:     ablls_data,
        preference: pref_data,
        sensory:   sensory_data
      }
    end

    # ─────────────────────────────────────────────────────────
    # Goals — all goals (active, mastered, archived)
    # ─────────────────────────────────────────────────────────

    def build_goals_summary(student)
      student.student_goals
             .includes(:goal, :therapy_station, :student_goal_steps, goal_mastery_checks: :goal_mastery_verifications)
             .order(updated_at: :desc)
             .map do |sg|
        # Full mastery check history, most recent first
        mastery_checks = sg.goal_mastery_checks.sort_by(&:created_at).reverse.map do |check|
          {
            id:                         check.id,
            status:                     check.status,
            primary_teacher_id:         check.initiating_teacher_id,
            submitted_at:               check.created_at,
            rejection_reason:           check.rejection_reason,
            verifications:              check.goal_mastery_verifications.map do |v|
              {
                id:          v.id,
                verifier_id: v.verifying_teacher_id,
                outcome:     v.outcome,
                prompt_used: v.prompt_used,
                notes:       v.notes,
                verified_at: v.created_at
              }
            end
          }
        end

        steps_data = sg.student_goal_steps.map do |step|
          {
            id:                  step.id,
            step_number:         step.step_number,
            description:         step.description,
            independence_percent: step.independence_percent.to_f,
            status:              step.status
          }
        end

        {
          id:                   sg.id,
          goal_id:              sg.goal_id,
          goal_name:            sg.goal&.name || "Goal",
          goal_type:            sg.goal&.goal_type || "standard",
          domain_name:          sg.goal&.goal_domain&.name || "General",
          station: {
            id:   sg.therapy_station&.id,
            name: sg.therapy_station&.name
          },
          status:               sg.status,
          progress_percent:     sg.progress_percent.to_f,
          clinical_note:        sg.clinical_note,
          task_analysis_steps:  steps_data,
          mastery_check_history: mastery_checks,
          latest_mastery_check:  mastery_checks.first,
          created_at:           sg.created_at,
          updated_at:           sg.updated_at
        }
      end
    end

    # ─────────────────────────────────────────────────────────
    # Session history — full paginated list
    # ─────────────────────────────────────────────────────────

    def build_session_history(student)
      base = SessionParticipant
        .where(student_id: student.id)
        .includes(therapy_session: [
          :session_block_definition,
          :therapy_station,
          :therapy_room,
          :session_summary,
          :teacher
        ])
        .joins(:therapy_session)
        .order("therapy_sessions.started_at DESC")

      total_sessions     = base.count
      completed_sessions = base.where(therapy_sessions: { status: "completed" }).count

      offset  = (@page - 1) * @per_page
      paged   = base.limit(@per_page).offset(offset).to_a
      trial_counts = Trial.where(session_participant_id: paged.map(&:id)).group(:session_participant_id).count

      sessions = paged.map do |part|
        session = part.therapy_session
        summary = session.session_summary

        {
          session_id:   session.id,
          started_at:   session.started_at,
          ended_at:     session.ended_at,
          status:       session.status,
          block_name:   session.session_block_definition&.name,
          station_name: session.therapy_station&.name,
          room_name:    session.therapy_room&.name,
          teacher_name: session.teacher&.full_name || "Assigned Teacher",
          trial_count:  trial_counts[part.id] || 0,
          summary:      summary ? {
            id:                 summary.id,
            status:             summary.status,
            qualitative_notes:  summary.qualitative_notes,
            reviewed_at:        summary.reviewed_at
          } : nil
        }
      end

      {
        total_sessions:     total_sessions,
        completed_sessions: completed_sessions,
        attendance_rate:    total_sessions.positive? ? ((completed_sessions.to_f / total_sessions) * 100).round(1) : 0.0,
        pagination: {
          page:        @page,
          per_page:    @per_page,
          total_pages: (total_sessions.to_f / @per_page).ceil,
          total_count: total_sessions
        },
        recent_sessions: sessions
      }
    end

    # ─────────────────────────────────────────────────────────
    # Trial performance — prompt level breakdown
    # ─────────────────────────────────────────────────────────

    def build_trial_performance(student)
      participants  = SessionParticipant.where(student_id: student.id)
      trials        = Trial.where(session_participant_id: participants.select(:id))

      total_trials  = trials.count
      prompt_counts = trials.joins(:prompt_level).group("prompt_levels.label").count

      breakdown = prompt_counts.map do |label, count|
        pct = total_trials.positive? ? ((count.to_f / total_trials) * 100).round(1) : 0.0
        { prompt_level: label || "Unknown", count: count, percentage: pct }
      end.sort_by { |b| -b[:count] }

      independent_trials     = prompt_counts["+"] || prompt_counts["Independent"] || 0
      overall_independence   = total_trials.positive? ? ((independent_trials.to_f / total_trials) * 100).round(1) : 0.0

      {
        total_trials:               total_trials,
        overall_independence_percent: overall_independence,
        prompt_breakdown:           breakdown
      }
    end

    # ─────────────────────────────────────────────────────────
    # Behavior incidents
    # ─────────────────────────────────────────────────────────

    def build_behavior_incident_trends(student)
      incidents = []
      if defined?(BehaviorIncident) && ActiveRecord::Base.connection.table_exists?("behavior_incidents")
        incidents    = BehaviorIncident.where(student_id: student.id).order(occurred_at: :desc)
      end

      total_incidents  = incidents.respond_to?(:count)  ? incidents.count  : 0
      recent_incidents = incidents.respond_to?(:first)  ? incidents.first(10) : []

      {
        total_incidents: total_incidents,
        recent_incidents: recent_incidents.map do |inc|
          {
            id:             inc.id,
            occurred_at:    inc.occurred_at,
            behavior_name:  inc.behavior_name,
            intensity:      inc.intensity,
            frequency:      inc.frequency,
            category:       inc.category,
            antecedent:     inc.antecedent,
            consequence:    inc.consequence,
            notes:          inc.additional_notes
          }
        end
      }
    end

    # ─────────────────────────────────────────────────────────
    # Goal progress charts (data points for trend lines)
    # ─────────────────────────────────────────────────────────

    def build_goal_progress_charts(student)
      student.student_goals.includes(:goal).order(created_at: :asc).map do |sg|
        current_pct = sg.progress_percent.to_f

        # Mastery checks carry no percentage, so the trend runs from assignment
        # (0%) to the goal's current progress.
        points = [
          { date: sg.created_at.to_date, progress_percent: 0.0 },
          { date: sg.updated_at.to_date, progress_percent: current_pct }
        ]

        {
          student_goal_id: sg.id,
          goal_name:       sg.goal&.name || "Goal",
          current_progress: current_pct,
          status:          sg.status,
          data_points:     points
        }
      end
    end

    # ─────────────────────────────────────────────────────────
    # Internal notes — FR-135 (Director / Admin only)
    # ─────────────────────────────────────────────────────────

    def build_internal_notes(student)
      notes_scope = student.internal_student_notes.internal.order(recorded_at: :desc)

      notes_count      = notes_scope.count
      latest_note      = notes_scope.first

      if director_or_admin?
        serialized = notes_scope.includes(author: :staff_member).map { |note| serialize_note(note) }
        {
          count:               notes_count,
          latest_recorded_at:  latest_note&.recorded_at,
          access_granted:      true,
          notes:               serialized
        }
      else
        # Non-directors see count only — no content, no authors
        {
          count:               notes_count,
          latest_recorded_at:  latest_note&.recorded_at,
          access_granted:      false,
          notes:               nil
        }
      end
    end

    # ─────────────────────────────────────────────────────────
    # Helpers
    # ─────────────────────────────────────────────────────────

    def director_or_admin?
      return false unless @current_user

      @current_user.has_any_role?(*Role::DIRECTOR_OR_ADMIN_ROLES)
    end

    def serialize_note(note)
      {
        id:          note.id,
        student_id:  note.student_id,
        author_id:   note.author_id,
        author_name: note.author&.staff_member&.full_name || note.author&.email || "Unknown",
        author_role: note.author&.primary_role&.name || "Staff",
        content:     note.content,
        recorded_at: note.recorded_at.iso8601,
        created_at:  note.created_at.iso8601
      }
    end
  end
end
