# frozen_string_literal: true

module Api
  module V1
    class IupGoalsController < Api::V1::BaseController
      include Authorization

      before_action :authenticate_user!
      before_action :set_current_user
      before_action :authorize_iup_management
      before_action :set_iup
      before_action :ensure_iup_is_draft, only: [ :create, :update, :destroy ]
      before_action :set_student_goal, only: [ :update, :destroy ]

      def create
        result = Iups::AssignGoalService.call(
          iup: @iup,
          goal: Goal.find(params[:goal_id]),
          therapy_station: TherapyStation.find(params[:therapy_station_id]),
          current_user: current_user
        )

        if result.success?
          student_goal = result.data[:student_goal]
          render json: {
            student_goal: {
              id: student_goal.id,
              goal: {
                id: student_goal.goal.id,
                name: student_goal.goal.name
              },
              therapy_station: {
                id: student_goal.therapy_station.id,
                name: student_goal.therapy_station.name
              },
              status: student_goal.status,
              progress_percent: student_goal.progress_percent,
              student_goal_steps: student_goal.student_goal_steps.map do |step|
                {
                  id: step.id,
                  step_number: step.step_number,
                  name: step.name,
                  description: step.description,
                  status: step.status,
                  independence_percent: step.independence_percent
                }
              end
            }
          }, status: :created
        else
          render_error(result.error, :unprocessable_entity)
        end
      end

      def update
        result = Iups::ReplaceGoalService.call(
          student_goal: @student_goal,
          new_goal: Goal.find(params[:new_goal_id]),
          current_user: current_user
        )

        if result.success?
          student_goal = result.data[:student_goal]
          render json: {
            student_goal: {
              id: student_goal.id,
              goal: {
                id: student_goal.goal.id,
                name: student_goal.goal.name
              },
              therapy_station: {
                id: student_goal.therapy_station.id,
                name: student_goal.therapy_station.name
              },
              status: student_goal.status,
              progress_percent: student_goal.progress_percent,
              student_goal_steps: student_goal.student_goal_steps.map do |step|
                {
                  id: step.id,
                  step_number: step.step_number,
                  name: step.name,
                  description: step.description,
                  status: step.status,
                  independence_percent: step.independence_percent
                }
              end
            }
          }, status: :ok
        else
          render_error(result.error, :unprocessable_entity)
        end
      end

      def destroy
        @student_goal.discard!

        AuditLog.create!(
          resource_type: "StudentGoal",
          resource_id: @student_goal.id.to_s,
          action: "goal_removed",
          user_id: current_user.id,
          change_data: {
            goal_name: @student_goal.goal.name,
            station_id: @student_goal.therapy_station_id,
            iup_id: @iup.id
          }
        )

        head :no_content
      end

      private

      def set_iup
        @iup = Iup.kept.find_by(id: params[:iup_id])
        render_not_found("IUP not found") unless @iup
      end

      def set_student_goal
        @student_goal = @iup.student_goals.kept.find_by(id: params[:id])
        render_not_found("Student goal not found") unless @student_goal
      end

      def ensure_iup_is_draft
        unless @iup.status_draft?
          render_error("Cannot modify goals on a #{@iup.status} IUP", :unprocessable_entity)
        end
      end
    end
  end
end
