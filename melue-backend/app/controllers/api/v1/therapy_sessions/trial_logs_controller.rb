# frozen_string_literal: true

module Api
  module V1
    module TherapySessions
      class TrialLogsController < Api::V1::BaseController
        include TeacherSessionScoped

        before_action :authenticate_user!
        before_action :require_staff_member!
        before_action :set_session
        before_action :authorize_teacher_session!
        before_action :set_participant
        before_action :set_student_goal

        # GET /api/v1/therapy_sessions/:therapy_session_id/participants/:participant_id/goals/:student_goal_id/trial_log
        #
        # Returns all trials for a specific participant and goal in chronological order.
        #
        # @oas_include
        # @summary Get chronological trial log for a student goal
        # @tags Active Therapy
        # @auth [bearer_jwt]
        # @response (200) Hash{ trials: Array<Hash> }
        # @response (404) Hash{ error: String }
        # @response (422) Hash{ error: String }
        def show
          trials = @session.trials
                          .where(session_participant_id: @participant.id, student_goal_id: @student_goal.id)
                          .order(logged_at: :asc, id: :asc)

          render json: { trials: TrialSerializer.new(trials).as_json }, status: :ok
        end

        private

        def set_participant
          @participant = @session.session_participants.find_by(id: params[:participant_id])
          render_not_found("Participant not found in this session") unless @participant
        end

        def set_student_goal
          @student_goal = StudentGoal.find_by(id: params[:student_goal_id])
          unless @student_goal && @student_goal.student_id == @participant.student_id
            render_error("Goal does not belong to this participant's student", :unprocessable_entity)
          end
        end
      end
    end
  end
end
