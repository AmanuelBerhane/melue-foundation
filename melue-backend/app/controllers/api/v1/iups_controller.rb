# frozen_string_literal: true

module Api
  module V1
    class IupsController < Api::V1::BaseController
      include Authorization

      before_action :authenticate_user!
      before_action :set_current_user
      before_action :authorize_iup_management, only: [ :create, :update, :destroy ]
      before_action :authorize_finalization, only: [ :finalize ]
      before_action :set_iup, only: [ :show, :update, :destroy, :validate, :finalize ]

      def create
        result = Iups::CreateService.call(
          student: Student.find(params[:student_id]),
          assessment_cycle: AssessmentCycle.find(params[:assessment_cycle_id]),
          current_user: current_user
        )

        if result.success?
          iup = result.data[:iup]
          render json: {
            iup: {
              id: iup.id,
              student_id: iup.student_id,
              assessment_cycle_id: iup.assessment_cycle_id,
              status: iup.status,
              created_at: iup.created_at,
              form_submission: iup.form_submission ? {
                id: iup.form_submission.id,
                values: iup.form_submission.values
              } : nil
            }
          }, status: :created
        else
          render_error(result.error, :unprocessable_entity)
        end
      end

      def index
        scope = Iup.kept.includes(:student, :assessment_cycle)

        scope = scope.where(status: params[:status]) if params[:status].present?

        if params[:student_name].present?
          sanitized_name = ActiveRecord::Base.sanitize_sql_like(params[:student_name].downcase)
          scope = scope.joins(:student).where(
            "LOWER(CONCAT(students.first_name, ' ', students.last_name)) LIKE ?",
            "%#{sanitized_name}%"
          )
        end

        scope = scope.where("iups.finalized_on >= ?", params[:date_from]) if params[:date_from].present?
        scope = scope.where("iups.finalized_on <= ?", params[:date_to]) if params[:date_to].present?

        page = [ params[:page].to_i, 1 ].max
        per_page = [ [ params[:per_page].to_i, 1 ].max, 100 ].min
        per_page = 50 if per_page == 1 && params[:per_page].blank?

        paginated_scope = scope.offset((page - 1) * per_page).limit(per_page)
        total_count = scope.count

        iups_payload = paginated_scope.map do |iup|
          {
            id: iup.id,
            student: {
              id: iup.student.id,
              name: iup.student.full_name
            },
            status: iup.status,
            finalized_on: iup.finalized_on,
            assessment_cycle_period: iup.assessment_cycle ?
              "#{iup.assessment_cycle.started_on} to #{iup.assessment_cycle.completed_on}" : nil,
            created_at: iup.created_at
          }
        end

        render json: {
          iups: iups_payload,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          }
        }, status: :ok
      end

      def show
        render json: {
          iup: {
            id: @iup.id,
            student: {
              id: @iup.student.id,
              name: @iup.student.full_name
            },
            status: @iup.status,
            finalized_on: @iup.finalized_on,
            form_submission: @iup.form_submission ? {
              id: @iup.form_submission.id,
              values: @iup.form_submission.values
            } : nil,
            student_goals: @iup.student_goals.includes(:goal, :therapy_station, :student_goal_steps).map do |sg|
              {
                id: sg.id,
                goal: {
                  id: sg.goal.id,
                  name: sg.goal.name,
                  description: sg.goal.description
                },
                therapy_station: {
                  id: sg.therapy_station.id,
                  name: sg.therapy_station.name
                },
                status: sg.status,
                progress_percent: sg.progress_percent,
                student_goal_steps: sg.student_goal_steps.map do |step|
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
            end,
            signatures: @iup.iup_signatures.map do |sig|
              {
                signer_role: sig.signer_role,
                signer_name: sig.signer_name,
                signed_at: sig.signed_at
              }
            end
          }
        }, status: :ok
      end

      def update
        unless @iup.status_draft?
          return render_error("Cannot update a finalized IUP", :unprocessable_entity)
        end

        if @iup.form_submission.nil?
          return render_error("Form submission not found", :unprocessable_entity)
        end

        form_values = params.require(:form_values)
        permitted_keys = @iup.form_submission.form_configuration.field_schema["fields"]&.map { |f| f["key"] } || []
        permitted_values = form_values.to_unsafe_h.slice(*permitted_keys)

        @iup.form_submission.update!(values: @iup.form_submission.values.merge(permitted_values))

        render json: {
          iup: {
            id: @iup.id,
            status: @iup.status
          },
          saved_at: Time.current
        }, status: :ok
      end

      def destroy
        unless @iup.status_draft?
          return render_error("Only draft IUPs can be deleted", :unprocessable_entity)
        end

        student_goal_count = @iup.student_goals.kept.count
        if student_goal_count > 0
          return render_error("Cannot delete IUP - #{student_goal_count} goal(s) must be removed first", :unprocessable_entity)
        end

        @iup.destroy!

        if @iup.errors[:base].any?
          return render_error(@iup.errors[:base].join(", "), :unprocessable_entity)
        end

        AuditLog.create!(
          resource_type: "Iup",
          resource_id: @iup.id.to_s,
          action: "iup_deleted",
          user_id: current_user.id,
          change_data: {
            student_id: @iup.student_id
          }
        )

        head :no_content
      end

      def validate
        result = Iups::ValidateService.call(iup: @iup)

        if result.success?
          render json: { valid: true, errors: [] }, status: :ok
        else
          render json: { valid: false, errors: result.error[:errors] }, status: :ok
        end
      end

      def finalize
        result = Iups::FinalizeService.call(
          iup: @iup,
          finalized_by_user: current_user
        )

        if result.success?
          render json: {
            iup: {
              id: result.data[:iup].id,
              status: result.data[:iup].status,
              finalized_on: result.data[:iup].finalized_on,
              student: {
                id: result.data[:iup].student.id,
                status: result.data[:iup].student.status
              }
            },
            message: "IUP finalized successfully - Student transitioned to Active Therapy"
          }, status: :ok
        else
          render_error(result.error, :unprocessable_entity)
        end
      end

      private

      def authorize_finalization
        unless current_user_has_role?([ "Program Director", "Director" ]) ||
               current_user&.has_role?(Role::Names::PROGRAM_DIRECTOR) ||
               current_user&.staff_member&.role_program_director? ||
               current_user&.staff_member&.role_admin?
          render_error("Only Program Directors can finalize IUPs", :forbidden)
        end
      end

      def set_iup
        @iup = Iup.kept.find_by(id: params[:id])
        render_not_found("IUP not found") unless @iup
      end
    end
  end
end
