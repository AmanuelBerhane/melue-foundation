# frozen_string_literal: true

module Api
  module V1
    # FR-071 to FR-078b: Goal Bank Controller
    # Manages the library of ABA goals, search, domain filter chips, CRUD,
    # deactivation, active student deletion protection, and Task Analysis templates.
    class GoalsController < Api::V1::BaseController
      include Authorization

      before_action :authenticate_user!
      before_action :require_program_director, only: %i[create update destroy deactivate activate upload_template import_template]
      before_action :set_goal, only: %i[show update destroy deactivate activate]

      # GET /api/v1/goals
      #
      # @summary Search and filter the Goal Bank
      # @tags Goal Bank
      # @auth [bearer_jwt]
      # @parameter q(query) [String] Search query by goal name or keyword (FR-072)
      # @parameter goal_domain_id(query) [String] Filter by domain ID (FR-073)
      # @parameter domain_ids(query) [Array<String>] Filter by multiple domain IDs (FR-073)
      # @parameter therapy_group(query) [String] Filter by therapy group
      # @parameter goal_type(query) [String] Filter by goal type (standard, task_analysis) (FR-078a)
      # @parameter is_active(query) [String] Filter by active status (true, false, all)
      # @parameter page(query) [Integer] Page number
      # @parameter per_page(query) [Integer] Items per page
      # @response (200) Hash{goals: Array<Hash>, pagination: Hash, domains: Array<Hash>}
      # @response (401) Hash{error: String}
      def index
        scope = filter_goals_scope

        page = [ params[:page].to_i, 1 ].max
        per_page = params[:per_page].present? ? [ params[:per_page].to_i, 100 ].min : 25

        total_count = scope.count
        goals = scope.offset((page - 1) * per_page).limit(per_page).to_a

        # Batch calculate usage counts to avoid N+1 queries (FR-078)
        usage_counts = usage_counts_for(goals.map(&:id))

        serialized_goals = goals.map do |goal|
          GoalSerializer.new(goal, usage_counts: usage_counts).as_json
        end

        # Preload domain filter chips with active goal counts (FR-073)
        domains_for_chips = available_domain_chips

        render json: {
          goals: serialized_goals,
          pagination: {
            current_page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: (total_count.to_f / per_page).ceil
          },
          domains: domains_for_chips
        }, status: :ok
      end

      # GET /api/v1/goals/:id
      #
      # @summary Get details of a single goal
      # @tags Goal Bank
      # @auth [bearer_jwt]
      # @parameter id(path) [!String] The goal UUID
      # @response (200) Hash
      # @response (404) Hash{error: String}
      def show
        render json: GoalSerializer.new(@goal).as_json, status: :ok
      end

      # POST /api/v1/goals
      #
      # @summary Add a new goal to the Goal Bank (SCR-PD-006, FR-074, FR-078a, FR-078b)
      # @tags Goal Bank
      # @auth [bearer_jwt]
      # @request_body Goal attributes or template [!Hash]
      # @response (201) Hash
      # @response (403) Hash{error: String}
      # @response (422) Hash{errors: Hash}
      def create
        # Support template file upload directly in create if file attached (FR-078b)
        template_file = params[:file] || params[:template_file]
        if template_file.present?
          result = Goals::ImportTemplateService.call(
            file: template_file,
            user: current_user,
            overrides: params[:goal].present? ? goal_params.to_h : {}
          )

          if result.success?
            render json: GoalSerializer.new(result.data).as_json, status: :created
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
          return
        end

        goal = Goal.new(goal_params)

        if goal.save
          AuditLog.create!(
            user_id: current_user&.id,
            action: "create_goal",
            resource_type: "Goal",
            resource_id: goal.id.to_s,
            metadata: { name: goal.name, goal_type: goal.goal_type }
          )

          render json: GoalSerializer.new(goal.reload).as_json, status: :created
        else
          render json: { errors: goal.errors }, status: :unprocessable_content
        end
      end

      # PUT/PATCH /api/v1/goals/:id
      #
      # @summary Edit existing goal details (FR-075)
      # @tags Goal Bank
      # @auth [bearer_jwt]
      # @parameter id(path) [!String] The goal UUID
      # @request_body Goal attributes [!Hash]
      # @response (200) Hash
      # @response (403) Hash{error: String}
      # @response (422) Hash{errors: Hash}
      def update
        if @goal.update(goal_params)
          AuditLog.create!(
            user_id: current_user&.id,
            action: "update_goal",
            resource_type: "Goal",
            resource_id: @goal.id.to_s,
            metadata: { name: @goal.name }
          )

          render json: GoalSerializer.new(@goal.reload).as_json, status: :ok
        else
          render json: { errors: @goal.errors }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/goals/:id
      #
      # @summary Delete a goal if not assigned to active students (FR-077)
      # @tags Goal Bank
      # @auth [bearer_jwt]
      # @parameter id(path) [!String] The goal UUID
      # @response (204) Head
      # @response (403) Hash{error: String}
      # @response (422) Hash{error: String}
      def destroy
        deletion_check = DeletionCheckService.call(@goal)

        if deletion_check.failure?
          render json: { error: deletion_check.error }, status: :unprocessable_content
          return
        end

        ActiveRecord::Base.transaction do
          if @goal.student_goals.exists?
            @goal.discard!
            @goal.update_column(:is_active, false)
          else
            @goal.destroy!
          end

          AuditLog.create!(
            user_id: current_user&.id,
            action: "delete_goal",
            resource_type: "Goal",
            resource_id: @goal.id.to_s,
            metadata: { name: @goal.name }
          )
        end

        head :no_content
      rescue ActiveRecord::RecordNotDestroyed => e
        render json: { error: e.record.errors.full_messages.join(", ") }, status: :unprocessable_content
      end

      # PATCH /api/v1/goals/:id/deactivate
      #
      # @summary Deactivate a goal, preventing new assignments while preserving existing (FR-076)
      # @tags Goal Bank
      # @auth [bearer_jwt]
      # @parameter id(path) [!String] The goal UUID
      # @response (200) Hash{message: String, goal: Hash}
      # @response (403) Hash{error: String}
      def deactivate
        @goal.deactivate!

        AuditLog.create!(
          user_id: current_user&.id,
          action: "deactivate_goal",
          resource_type: "Goal",
          resource_id: @goal.id.to_s,
          metadata: { name: @goal.name }
        )

        render json: {
          message: "Goal successfully deactivated",
          goal: GoalSerializer.new(@goal).as_json
        }, status: :ok
      end

      # PATCH /api/v1/goals/:id/activate
      #
      # @summary Reactivate a previously deactivated goal
      # @tags Goal Bank
      # @auth [bearer_jwt]
      # @parameter id(path) [!String] The goal UUID
      # @response (200) Hash{message: String, goal: Hash}
      # @response (403) Hash{error: String}
      def activate
        @goal.activate!

        AuditLog.create!(
          user_id: current_user&.id,
          action: "activate_goal",
          resource_type: "Goal",
          resource_id: @goal.id.to_s,
          metadata: { name: @goal.name }
        )

        render json: {
          message: "Goal successfully activated",
          goal: GoalSerializer.new(@goal).as_json
        }, status: :ok
      end

      # POST /api/v1/goals/upload_template
      #
      # @summary Upload a predefined task analysis template (JSON/CSV) (FR-078b)
      # @tags Goal Bank
      # @auth [bearer_jwt]
      # @request_body Template file or data [!Hash]
      # @response (201) Hash
      # @response (403) Hash{error: String}
      # @response (422) Hash{error: String}
      def upload_template
        file = params[:file] || params[:template_file]
        template_data = params[:template] || params[:template_data]

        if file.blank? && template_data.blank?
          render json: { error: "Please provide a template file (JSON or CSV) or template data" },
                 status: :unprocessable_content
          return
        end

        result = Goals::ImportTemplateService.call(
          file: file,
          template_data: template_data,
          user: current_user,
          overrides: template_overrides
        )

        if result.success?
          render json: GoalSerializer.new(result.data).as_json, status: :created
        else
          render json: { error: result.error }, status: :unprocessable_content
        end
      end

      # Alias for upload_template
      alias_method :import_template, :upload_template

      # GET /api/v1/goals/search
      #
      # Legacy/dedicated search endpoint for ABA goals (FR-072)
      def search
        index
      end

      private

      def set_goal
        @goal = Goal.kept.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Goal not found" }, status: :not_found
      end

      def goal_params
        permitted = params.require(:goal).permit(
          :name, :task_name, :description, :goal_domain_id, :goal_type,
          :suggested_age_range, :is_active,
          applicable_therapy_groups: [],
          mastery_criteria: {},
          steps: [
            :id, :step_number, :name, :description, :_destroy,
            { mastery_criteria: {} }
          ],
          task_analysis_step_templates_attributes: [
            :id, :step_number, :name, :description, :_destroy,
            { mastery_criteria: {} }
          ]
        )

        # Allow task_name as alias for name (FR-078b)
        permitted[:name] = permitted.delete(:task_name) if permitted[:task_name].present? && permitted[:name].blank?

        if permitted[:steps].present?
          incoming_steps = permitted.delete(:steps)
          incoming_ids = incoming_steps.map { |s| s[:id]&.to_s }.compact

          steps_attrs = incoming_steps.map.with_index(1) do |step, idx|
            h = step.to_h.with_indifferent_access
            h[:step_number] = (h[:step_number].presence || idx).to_i
            h
          end

          if @goal&.persisted?
            existing_ids = @goal.task_analysis_step_templates.pluck(:id).map(&:to_s)
            (existing_ids - incoming_ids).each do |omitted_id|
              steps_attrs << { id: omitted_id, _destroy: true }
            end
          end

          permitted[:task_analysis_step_templates_attributes] = steps_attrs
        end

        permitted
      end

      def template_overrides
        overrides = {}
        if params[:goal].present?
          overrides = goal_params.to_h.with_indifferent_access
        else
          overrides[:goal_domain_id] = params[:goal_domain_id] || params[:domain_id]
          overrides[:name] = params[:name] || params[:task_name]
          overrides[:suggested_age_range] = params[:suggested_age_range]
          overrides[:applicable_therapy_groups] = params[:applicable_therapy_groups]
        end
        overrides
      end

      def filter_goals_scope
        scope = Goal.kept.includes(:goal_domain)

        # Active status filter
        if params[:is_active] == "false" || params[:status] == "inactive"
          scope = scope.where(is_active: false)
        elsif params[:is_active] == "all" || params[:status] == "all"
          # no active filter
        elsif params[:is_active] == "true" || params[:status] == "active"
          scope = scope.where(is_active: true)
        elsif params[:action] == "search"
          scope = scope.where(is_active: true)
        else
          # Default to active goals for bank view unless specified
          scope = scope.where(is_active: true)
        end

        # Domain filter chips (FR-073)
        domain_ids = Array(params[:domain_ids]).compact_blank
        domain_ids += params[:domain_ids].to_s.split(",") if params[:domain_ids].is_a?(String)
        domain_ids << params[:goal_domain_id] if params[:goal_domain_id].present?
        domain_ids << params[:domain_id] if params[:domain_id].present?
        domain_ids = domain_ids.uniq.compact_blank

        if domain_ids.any?
          scope = scope.where(goal_domain_id: domain_ids)
        elsif params[:domain].present? || params[:domain_name].present?
          domain_name = params[:domain] || params[:domain_name]
          scope = scope.joins(:goal_domain).where("LOWER(goal_domains.name) = ?", domain_name.downcase)
        end

        # Search by goal name or keyword (FR-072)
        search_query = params[:q] || params[:query] || params[:search] || params[:keyword]
        if search_query.present?
          scope = scope.search_text(search_query)
        end

        # Filter by therapy group
        if params[:therapy_group].present?
          scope = scope.for_therapy_group(params[:therapy_group])
        end

        # Filter by goal type (FR-078a)
        if params[:goal_type].present?
          scope = scope.where(goal_type: params[:goal_type])
        end

        scope.order(:name)
      end

      def usage_counts_for(goal_ids)
        return {} if goal_ids.blank?

        StudentGoal
          .kept
          .where(goal_id: goal_ids, status: %w[active in_progress])
          .joins(:student)
          .where(students: { discarded_at: nil })
          .where.not(students: { status: %w[withdrawn discharged archived] })
          .group(:goal_id)
          .count("DISTINCT student_goals.student_id")
      end

      def available_domain_chips
        domains = GoalDomain.active.order(:display_order)
        counts = Goal.kept.active.group(:goal_domain_id).count

        domains.map do |domain|
          {
            id: domain.id,
            name: domain.name,
            display_order: domain.display_order,
            goal_count: counts[domain.id] || 0
          }
        end
      end
    end
  end
end
