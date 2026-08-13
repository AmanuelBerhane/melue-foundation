module Api
  module V1
    module Admin
      class GoalDomainsController < BaseController
        before_action :set_goal_domain, only: [ :show, :update, :destroy ]

        # GET /api/v1/admin/goal_domains
        #
        # Returns all goal domains ordered by display_order.
        #
        # @summary List all goal domains
        # @tags Goal Domains
        # @auth [bearer_jwt]
        # @response Goal domains list(200) [Array<Hash{id: Integer, name: String, description: String, display_order: Integer, is_active: Boolean}>]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def index
          goal_domains = GoalDomain.order(:display_order)
          render json: goal_domains
        end

        # GET /api/v1/admin/goal_domains/:id
        #
        # Returns a single goal domain by ID.
        #
        # @summary Get a goal domain
        # @tags Goal Domains
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The goal domain ID
        # @response Goal domain(200) [Hash{id: Integer, name: String, description: String, display_order: Integer, is_active: Boolean}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def show
          render json: @goal_domain
        end

        # POST /api/v1/admin/goal_domains
        #
        # Creates a new goal domain. Names must be unique (case-insensitive).
        #
        # @summary Create a goal domain
        # @tags Goal Domains
        # @auth [bearer_jwt]
        # @request_body Goal domain attributes [!Hash{goal_domain: Hash{name: String, description: String, display_order: Integer, is_active: Boolean}}]
        # @response Goal domain created(201) [Hash{id: Integer, name: String, description: String, display_order: Integer, is_active: Boolean}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def create
          goal_domain = GoalDomain.new(goal_domain_params)

          if goal_domain.save
            render json: goal_domain, status: :created
          else
            render json: { errors: goal_domain.errors }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/goal_domains/:id
        #
        # Updates an existing goal domain.
        #
        # @summary Update a goal domain
        # @tags Goal Domains
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The goal domain ID
        # @request_body Goal domain attributes [!Hash{goal_domain: Hash{name: String, description: String, display_order: Integer, is_active: Boolean}}]
        # @response Goal domain updated(200) [Hash{id: Integer, name: String, description: String, display_order: Integer, is_active: Boolean}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def update
          if @goal_domain.update(goal_domain_params)
            render json: @goal_domain
          else
            render json: { errors: @goal_domain.errors }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/goal_domains/:id
        #
        # Deletes a goal domain. Returns 422 if the domain has associated goals.
        #
        # @summary Delete a goal domain
        # @tags Goal Domains
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The goal domain ID
        # @response Goal domain deleted(204)
        # @response Cannot delete - has dependencies(422) [Hash{error: String}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def destroy
          deletion_check = DeletionCheckService.call(@goal_domain)

          if deletion_check.failure?
            render json: { error: deletion_check.error }, status: :unprocessable_entity
            return
          end

          @goal_domain.destroy
          head :no_content
        end

        # PUT /api/v1/admin/goal_domains/reorder
        #
        # Reorders goal domains by accepting an ordered array of IDs.
        # Updates display_order based on array index (0-based).
        #
        # @summary Reorder goal domains
        # @tags Goal Domains
        # @auth [bearer_jwt]
        # @request_body Ordered IDs [!Hash{ids: Array<Integer>}]
        # @response Reordered successfully(200)
        # @response Invalid IDs or reorder error(422) [Hash{error: String}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def reorder
          result = ReorderService.call(GoalDomain, params[:ids])

          if result.success?
            AuditLog.create!(
              user_id: Current.user&.id,
              action: "reorder",
              resource_type: "GoalDomain",
              metadata: { ids: params[:ids] }
            )
            head :ok
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        private

        def set_goal_domain
          @goal_domain = GoalDomain.find(params[:id])
        end

        def goal_domain_params
          params.require(:goal_domain).permit(:name, :description, :display_order, :is_active)
        end
      end
    end
  end
end
