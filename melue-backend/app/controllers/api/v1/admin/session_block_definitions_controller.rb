module Api
  module V1
    module Admin
      class SessionBlockDefinitionsController < BaseController
        before_action :set_session_block_definition, only: [ :show, :update, :destroy ]

        # GET /api/v1/admin/session_block_definitions
        #
        # Returns all session block definitions ordered by start_time.
        #
        # @summary List all session block definitions
        # @tags Session Block Definitions
        # @auth [bearer_jwt]
        # @response Session block definitions list(200) [Array<Hash{id: Integer, name: String, start_time: String, end_time: String, round: String, is_active: Boolean}>]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def index
          session_block_definitions = SessionBlockDefinition.ordered
          render json: session_block_definitions
        end

        # GET /api/v1/admin/session_block_definitions/:id
        #
        # Returns a single session block definition by ID.
        #
        # @summary Get a session block definition
        # @tags Session Block Definitions
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The session block definition ID
        # @response Session block definition(200) [Hash{id: Integer, name: String, start_time: String, end_time: String, round: String, is_active: Boolean}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def show
          render json: @session_block_definition
        end

        # POST /api/v1/admin/session_block_definitions
        #
        # Creates a new session block definition. end_time must be after start_time.
        #
        # @summary Create a session block definition
        # @tags Session Block Definitions
        # @auth [bearer_jwt]
        # @request_body Session block definition attributes [!Hash{session_block_definition: Hash{name: String, start_time: String, end_time: String, round: String, is_active: Boolean}}]
        # @response Session block definition created(201) [Hash{id: Integer, name: String, start_time: String, end_time: String, round: String, is_active: Boolean}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def create
          session_block_definition = SessionBlockDefinition.new(session_block_definition_params)

          if session_block_definition.save
            render json: session_block_definition, status: :created
          else
            render json: { errors: session_block_definition.errors }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/session_block_definitions/:id
        #
        # Updates an existing session block definition. end_time must be after start_time.
        #
        # @summary Update a session block definition
        # @tags Session Block Definitions
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The session block definition ID
        # @request_body Session block definition attributes [!Hash{session_block_definition: Hash{name: String, start_time: String, end_time: String, round: String, is_active: Boolean}}]
        # @response Session block definition updated(200) [Hash{id: Integer, name: String, start_time: String, end_time: String, round: String, is_active: Boolean}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def update
          if @session_block_definition.update(session_block_definition_params)
            render json: @session_block_definition
          else
            render json: { errors: @session_block_definition.errors }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/session_block_definitions/:id
        #
        # Deletes a session block definition. Returns 422 if it has associated therapy sessions.
        #
        # @summary Delete a session block definition
        # @tags Session Block Definitions
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The session block definition ID
        # @response Session block definition deleted(204)
        # @response Cannot delete - has dependencies(422) [Hash{error: String}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def destroy
          deletion_check = DeletionCheckService.call(@session_block_definition)

          if deletion_check.failure?
            render json: { error: deletion_check.error }, status: :unprocessable_entity
            return
          end

          @session_block_definition.destroy
          head :no_content
        end

        private

        def set_session_block_definition
          @session_block_definition = SessionBlockDefinition.find(params[:id])
        end

        def session_block_definition_params
          params.require(:session_block_definition).permit(:name, :start_time, :end_time, :round, :is_active)
        end
      end
    end
  end
end
