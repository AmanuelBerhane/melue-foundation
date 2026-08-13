module Api
  module V1
    module Admin
      class FormConfigurationsController < BaseController
        before_action :set_form_configuration, only: [ :show, :update, :destroy, :import, :export ]

        # GET /api/v1/admin/form_configurations
        #
        # Returns all form configurations.
        #
        # @summary List all form configurations
        # @tags Form Configurations
        # @auth [bearer_jwt]
        # @response Form configurations list(200) [Array<Hash{id: Integer, form_name: String, form_type: String, revision_number: Integer, revision_date: String, organization_name: String, is_default: Boolean}>]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def index
          form_configurations = FormConfiguration.all
          render json: form_configurations
        end

        # GET /api/v1/admin/form_configurations/:id
        #
        # Returns a single form configuration including its full field_schema.
        #
        # @summary Get a form configuration
        # @tags Form Configurations
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The form configuration ID
        # @response Form configuration with field_schema(200) [Hash{id: Integer, form_name: String, form_type: String, revision_number: Integer, revision_date: String, organization_name: String, is_default: Boolean, field_schema: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def show
          render json: @form_configuration
        end

        # POST /api/v1/admin/form_configurations
        #
        # Creates a new form configuration. field_schema must contain a 'fields' array
        # with unique IDs and only supported field types.
        #
        # @summary Create a form configuration
        # @tags Form Configurations
        # @auth [bearer_jwt]
        # @request_body Form configuration attributes [!Hash{form_configuration: Hash{form_name: String, form_type: String, organization_name: String, is_default: Boolean, field_schema: Hash}}]
        # @response Form configuration created(201) [Hash{id: Integer, form_name: String, form_type: String, revision_number: Integer, revision_date: String, is_default: Boolean, field_schema: Hash}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        def create
          form_configuration = FormConfiguration.new(form_configuration_params)

          if form_configuration.save
            render json: form_configuration, status: :created
          else
            render json: { errors: form_configuration.errors }, status: :unprocessable_entity
          end
        end

        # PUT /api/v1/admin/form_configurations/:id
        #
        # Updates an existing form configuration.
        #
        # @summary Update a form configuration
        # @tags Form Configurations
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The form configuration ID
        # @request_body Form configuration attributes [!Hash{form_configuration: Hash{form_name: String, form_type: String, organization_name: String, is_default: Boolean, field_schema: Hash}}]
        # @response Form configuration updated(200) [Hash{id: Integer, form_name: String, form_type: String, revision_number: Integer, revision_date: String, is_default: Boolean, field_schema: Hash}]
        # @response Validation errors(422) [Hash{errors: Hash}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def update
          if @form_configuration.update(form_configuration_params)
            render json: @form_configuration
          else
            render json: { errors: @form_configuration.errors }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/admin/form_configurations/:id
        #
        # Deletes a form configuration.
        #
        # @summary Delete a form configuration
        # @tags Form Configurations
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The form configuration ID
        # @response Form configuration deleted(204)
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def destroy
          @form_configuration.destroy
          head :no_content
        end

        # POST /api/v1/admin/form_configurations/:id/import
        #
        # Imports a JSON template file to replace the field_schema of a form configuration.
        # Increments revision_number on success. Max file size: 10MB.
        #
        # @summary Import a form template JSON file
        # @tags Form Configurations
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The form configuration ID
        # @request_body JSON template file (multipart/form-data) [!Hash{file: String}]
        # @response Template imported successfully(200) [Hash{id: Integer, form_name: String, revision_number: Integer, field_schema: Hash}]
        # @response File required or invalid JSON content(422) [Hash{error: String}]
        # @response Unsupported media type - must be application/json(415) [Hash{error: String}]
        # @response File exceeds 10MB limit(413) [Hash{error: String}]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def import
          file = params[:file]

          if file.blank?
            render json: { error: "File is required" }, status: :unprocessable_entity
            return
          end

          if file.content_type != "application/json"
            render json: { error: "Content-Type must be application/json" }, status: :unsupported_media_type
            return
          end

          if file.size > 10.megabytes
            render json: { error: "File too large (max 10MB)" }, status: :payload_too_large
            return
          end

          result = FormTemplateImportService.call(@form_configuration, file)

          if result.success?
            AuditLog.create!(
              user_id: Current.user&.id,
              action: "import",
              resource_type: "FormConfiguration",
              resource_id: @form_configuration.id
            )
            render json: result.data
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        # GET /api/v1/admin/form_configurations/:id/export
        #
        # Exports the field_schema as a downloadable JSON file.
        # The filename is derived from the form_name and current date.
        #
        # @summary Export form configuration as JSON
        # @tags Form Configurations
        # @auth [bearer_jwt]
        # @parameter id(path) [!Integer] The form configuration ID
        # @response field_schema as downloadable JSON file(200) [Hash]
        # @response Unauthorized(401) [Hash{error: String}]
        # @response Forbidden(403) [Hash{error: String}]
        # @response Not found(404) [Hash{error: String}]
        def export
          json_data = JSON.pretty_generate(@form_configuration.field_schema, indent: "  ")

          AuditLog.create!(
            user_id: Current.user&.id,
            action: "export",
            resource_type: "FormConfiguration",
            resource_id: @form_configuration.id
          )

          send_data json_data,
                    filename: "#{@form_configuration.form_name.parameterize}-#{Date.current}.json",
                    type: "application/json",
                    disposition: "attachment"
        end

        private

        def set_form_configuration
          @form_configuration = FormConfiguration.find(params[:id])
        end

        def form_configuration_params
          params.require(:form_configuration).permit(:form_type, :form_name, :revision_date, :organization_name, :is_default, field_schema: {})
        end
      end
    end
  end
end
