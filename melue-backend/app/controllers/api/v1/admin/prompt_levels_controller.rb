module Api
  module V1
    module Admin
      class PromptLevelsController < BaseController
        before_action :set_prompt_level, only: [ :show, :update, :destroy ]

        # GET /api/v1/admin/prompt_levels
        #
        # Returns all prompt levels ordered by display_order.
        #
        # @summary List all prompt levels
        # @tags Prompt Levels
        # @auth [bearer_jwt]
        # @response Prompt levels list(200) [Array<Hash{id: Integer, label: String, color: String, display_order: Integer, is_active: Boolean}>]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def index
          prompt_levels = PromptLevel.order(:display_order)
          render json: prompt_levels
        end

        # GET /api/v1/admin/prompt_levels/:id
        #
        # Returns a single prompt level by ID.
        #
        # @summary Get a prompt level
        # @tags Prompt Levels
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The prompt level ID
        # @response Prompt level(200) [Hash{id: Integer, label: String, color: String, display_order: Integer, is_active: Boolean}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def show
          render json: @prompt_level
        end

        # POST /api/v1/admin/prompt_levels
        #
        # Creates a new prompt level. Color must be a valid hex code (e.g. #FF0000 or FF0000).
        #
        # @summary Create a prompt level
        # @tags Prompt Levels
        # @auth [bearer_jwt]
        # @request_body Prompt level attributes [!Hash{prompt_level: Hash{label: String, color: String, display_order: Integer, is_active: Boolean}}]
        # @response Prompt level created(201) [Hash{id: Integer, label: String, color: String, display_order: Integer, is_active: Boolean}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def create
          if params[:prompt_levels].is_a?(Array) || params[:promptLevels].is_a?(Array)
            return save_trial_config
          end

          prompt_level = PromptLevel.new(prompt_level_params)

          if prompt_level.save
            render json: prompt_level, status: :created
          else
            render json: { errors: prompt_level.errors }, status: :unprocessable_content
          end
        end

        # PUT /api/v1/admin/prompt_levels/:id
        #
        # Updates an existing prompt level.
        #
        # @summary Update a prompt level
        # @tags Prompt Levels
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The prompt level ID
        # @request_body Prompt level attributes [!Hash{prompt_level: Hash{label: String, color: String, display_order: Integer, is_active: Boolean}}]
        # @response Prompt level updated(200) [Hash{id: Integer, label: String, color: String, display_order: Integer, is_active: Boolean}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def update
          if @prompt_level.update(prompt_level_params)
            render json: @prompt_level
          else
            render json: { errors: @prompt_level.errors }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/admin/prompt_levels/:id
        #
        # Deletes a prompt level. Returns 422 if the level has associated trials.
        #
        # @summary Delete a prompt level
        # @tags Prompt Levels
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The prompt level ID
        # @response Prompt level deleted(204)
        # @response Cannot delete - has dependencies(422) [Hash{error: String}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def destroy
          deletion_check = DeletionCheckService.call(@prompt_level)

          if deletion_check.failure?
            render json: { error: deletion_check.error }, status: :unprocessable_content
            return
          end

          @prompt_level.destroy
          head :no_content
        end

        # PUT /api/v1/admin/prompt_levels/reorder
        #
        # Reorders prompt levels by accepting an ordered array of IDs.
        # Updates display_order based on array index (0-based).
        #
        # @summary Reorder prompt levels
        # @tags Prompt Levels
        # @auth [bearer_jwt]
        # @request_body Ordered IDs [!Hash{ids: Array<Integer>}]
        # @response Reordered successfully(200)
        # @response Invalid IDs or reorder error(422) [Hash{error: String}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def reorder
          result = ReorderService.call(PromptLevel, params[:ids])

          if result.success?
            AuditLog.create!(
              user_id: Current.user&.id,
              action: "reorder",
              resource_type: "PromptLevel",
              metadata: { ids: params[:ids] }
            )
            head :ok
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        # GET /api/v1/admin/trial-logging-config
        def show_trial_config
          config = Rails.cache.read("admin_trial_logging_config") || {
            "layout" => "Horizontal",
            "streamCount" => 5,
            "consecutive" => 5,
            "independence" => 80,
            "autoSuggest" => true
          }

          render json: {
            status: "ok",
            prompt_levels: PromptLevel.order(:display_order),
            layout: config["layout"],
            trialStreamLayout: config["layout"],
            streamCount: config["streamCount"],
            trialStreamCount: config["streamCount"],
            consecutive: config["consecutive"],
            masteryConsecutiveTrials: config["consecutive"],
            independence: config["independence"],
            independenceThreshold: config["independence"],
            autoSuggest: config["autoSuggest"]
          }
        end

        # POST /api/v1/admin/trial-logging-config
        def save_trial_config
          levels_param = params[:prompt_levels] || params[:promptLevels]
          if levels_param.is_a?(Array)
            levels_param.each_with_index do |pl, idx|
              level = PromptLevel.find_by(id: pl[:id]) if pl[:id].present?
              level ||= PromptLevel.find_or_initialize_by(label: pl[:name] || pl[:label])
              level.label = pl[:name] || pl[:label] if (pl[:name] || pl[:label]).present?
              level.color = pl[:color] if pl[:color].present?
              level.display_order = pl[:order] || pl[:display_order] || pl[:displayOrder] || idx
              level.is_active = (pl[:status].to_s.downcase != "inactive" && pl[:is_active] != false && pl[:isActive] != false)
              level.save if level.valid?
            end
          end

          layout = params[:layout] || params[:trialStreamLayout] || "Horizontal"
          stream_count = (params[:streamCount] || params[:trialStreamCount] || 5).to_i
          consecutive = (params[:consecutive] || params[:masteryConsecutiveTrials] || 5).to_i
          independence = (params[:independence] || params[:independenceThreshold] || 80).to_i
          auto_suggest = params.key?(:autoSuggest) ? ActiveModel::Type::Boolean.new.cast(params[:autoSuggest]) : true

          config = {
            "layout" => layout,
            "streamCount" => stream_count,
            "consecutive" => consecutive,
            "independence" => independence,
            "autoSuggest" => auto_suggest
          }
          Rails.cache.write("admin_trial_logging_config", config)

          render json: {
            status: "ok",
            message: "Trial logging format saved successfully",
            prompt_levels: PromptLevel.order(:display_order),
            layout: layout,
            trialStreamLayout: layout,
            streamCount: stream_count,
            trialStreamCount: stream_count,
            consecutive: consecutive,
            masteryConsecutiveTrials: consecutive,
            independence: independence,
            independenceThreshold: independence,
            autoSuggest: auto_suggest
          }
        end

        private

        def set_prompt_level
          id = params[:id].to_s.strip
          uuid_regex = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
          @prompt_level = if uuid_regex.match?(id)
                            PromptLevel.find_by(id: id)
                          else
                            PromptLevel.find_by("lower(label) = ?", id.downcase) ||
                              PromptLevel.order(:display_order).offset([id.scan(/\d+/).first.to_i - 1, 0].max).first
                          end

          unless @prompt_level
            render json: { error: "Prompt level not found" }, status: :not_found
          end
        end

        def prompt_level_params
          raw = params[:prompt_level] || params
          raw.permit(:label, :name, :color, :display_order, :order, :is_active).tap do |p|
            p[:label] = p.delete(:name) if p[:name].present? && p[:label].blank?
            p[:display_order] = p.delete(:order) if p[:order].present? && p[:display_order].blank?
          end
        end
      end
    end
  end
end
