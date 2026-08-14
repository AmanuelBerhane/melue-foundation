module Api
  module V1
    module Admin
      class AbcDropdownOptionsController < BaseController
        before_action :set_abc_dropdown_option, only: [ :show, :update, :destroy ]

        # GET /api/v1/admin/abc_dropdown_options
        #
        # Returns all ABC dropdown options. Optionally filter by category.
        # Results are ordered by display_order within each category.
        #
        # @summary List ABC dropdown options
        # @tags ABC Dropdown Options
        # @auth [bearer_jwt]
        # @parameter category(query) [String] Filter by category. enum: (antecedent,behavior,consequence)
        # @response ABC dropdown options list(200) [Array<Hash{id: Integer, label: String, category: String, display_order: Integer, is_active: Boolean, is_other: Boolean}>]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def index
          options = if params[:category].present?
            AbcDropdownOption.by_category(params[:category])
          else
            AbcDropdownOption.all.order(:category, :display_order)
          end
          render json: options
        end

        # GET /api/v1/admin/abc_dropdown_options/:id
        #
        # Returns a single ABC dropdown option by ID.
        #
        # @summary Get an ABC dropdown option
        # @tags ABC Dropdown Options
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The ABC dropdown option ID
        # @response ABC dropdown option(200) [Hash{id: Integer, label: String, category: String, display_order: Integer, is_active: Boolean, is_other: Boolean}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def show
          render json: @abc_dropdown_option
        end

        # POST /api/v1/admin/abc_dropdown_options
        #
        # Creates a new ABC dropdown option. Only one is_other option is allowed per category.
        #
        # @summary Create an ABC dropdown option
        # @tags ABC Dropdown Options
        # @auth [bearer_jwt]
        # @request_body ABC dropdown option attributes [!Hash{abc_dropdown_option: Hash{label: String, category: String, display_order: Integer, is_active: Boolean, is_other: Boolean}}]
        # @response ABC dropdown option created(201) [Hash{id: Integer, label: String, category: String, display_order: Integer, is_active: Boolean, is_other: Boolean}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def create
          abc_dropdown_option = AbcDropdownOption.new(abc_dropdown_option_params)

          if abc_dropdown_option.save
            render json: abc_dropdown_option, status: :created
          else
            render json: { errors: abc_dropdown_option.errors }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/abc_dropdown_options/:id
        #
        # Updates an existing ABC dropdown option.
        #
        # @summary Update an ABC dropdown option
        # @tags ABC Dropdown Options
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The ABC dropdown option ID
        # @request_body ABC dropdown option attributes [!Hash{abc_dropdown_option: Hash{label: String, category: String, display_order: Integer, is_active: Boolean, is_other: Boolean}}]
        # @response ABC dropdown option updated(200) [Hash{id: Integer, label: String, category: String, display_order: Integer, is_active: Boolean, is_other: Boolean}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def update
          if @abc_dropdown_option.update(abc_dropdown_option_params)
            render json: @abc_dropdown_option
          else
            render json: { errors: @abc_dropdown_option.errors }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/abc_dropdown_options/:id
        #
        # Deletes an ABC dropdown option.
        #
        # @summary Delete an ABC dropdown option
        # @tags ABC Dropdown Options
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The ABC dropdown option ID
        # @response ABC dropdown option deleted(204)
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def destroy
          @abc_dropdown_option.destroy
          head :no_content
        end

        # PUT /api/v1/admin/abc_dropdown_options/reorder
        #
        # Reorders ABC dropdown options within a specific category.
        # The category param is required. Updates display_order based on array index.
        #
        # @summary Reorder ABC dropdown options within a category
        # @tags ABC Dropdown Options
        # @auth [bearer_jwt]
        # @request_body Ordered IDs with category [!Hash{category: String, ids: Array<Integer>}]
        # @response Reordered successfully(200)
        # @response Category is required or invalid IDs(422) [Hash{error: String}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def reorder
          category = params[:category]
          ids = params[:ids]

          if category.blank?
            render json: { error: "Category is required" }, status: :unprocessable_entity
            return
          end

          result = ReorderService.call(AbcDropdownOption.where(category: category), ids)

          if result.success?
            AuditLog.create!(
              user_id: Current.user&.id,
              action: "reorder",
              resource_type: "AbcDropdownOption",
              metadata: { ids: ids, category: category }
            )
            head :ok
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        private

        def set_abc_dropdown_option
          @abc_dropdown_option = AbcDropdownOption.find(params[:id])
        end

        def abc_dropdown_option_params
          params.require(:abc_dropdown_option).permit(:label, :category, :display_order, :is_active, :is_other)
        end
      end
    end
  end
end
