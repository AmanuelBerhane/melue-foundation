# frozen_string_literal: true

module Api
  module V1
    module Admin
      class FormsController < BaseController
        before_action :authenticate_user!
        before_action :set_form_config, except: [:index]

        # GET /api/v1/admin/forms
        def index
          configs = FormConfiguration.all.order(:form_name)
          is_empty = configs.empty?

          render json: {
            forms: configs.map do |fc|
              schema = fc.field_schema || empty_field_schema
              fields = schema["fields"] || []
              {
                id: fc.id,
                formName: fc.form_name,
                formType: fc.form_type,
                revisionNumber: fc.revision_number || 1,
                isDefault: fc.is_default,
                fieldCount: fields.size,
                isEmpty: fields.empty?,
                emptyState: fields.empty? ? empty_state_metadata(fc.form_name) : nil
              }
            end,
            isEmpty: is_empty,
            emptyState: is_empty ? {
              title: "No Form Configurations",
              message: "No forms have been configured in the database yet. Run db:seed to populate standard forms.",
              action: "seed_forms"
            } : nil
          }
        end

        # GET /api/v1/admin/forms/:form_name
        def show
          schema = @form_config.field_schema || empty_field_schema
          fields = schema["fields"] || []
          is_empty = fields.empty?

          render json: {
            formName: @form_config.form_name,
            formType: @form_config.form_type,
            revisionNumber: @form_config.revision_number || 1,
            isDefault: @form_config.is_default,
            fields: fields,
            customSections: schema["customSections"] || schema["sections"] || [],
            deletedSections: schema["deletedSections"] || [],
            history: schema["history"] || [],
            isEmpty: is_empty,
            emptyState: is_empty ? empty_state_metadata : nil
          }
        end

        # POST /api/v1/admin/forms/:form_name
        def update_config
          payload = begin
            parsed = JSON.parse(request.raw_post) rescue nil
            parsed.is_a?(Hash) ? parsed : request.request_parameters.except("controller", "action", "form_name")
          end

          fields = payload["fields"] || []
          custom_sections = payload["customSections"] || payload["sections"] || []
          deleted_sections = payload["deletedSections"] || []
          history = payload["history"] || []
          is_default = payload["isDefault"] == true
          is_empty = fields.empty?

          schema = {
            "fields" => fields,
            "customSections" => custom_sections,
            "deletedSections" => deleted_sections,
            "history" => history
          }

          @form_config.field_schema = schema
          @form_config.is_default = is_default
          @form_config.revision_number = (@form_config.revision_number || 1) + 1
          @form_config.revision_date = Date.current
          @form_config.save!

          render json: {
            formName: @form_config.form_name,
            formType: @form_config.form_type,
            revisionNumber: @form_config.revision_number,
            isDefault: @form_config.is_default,
            fields: fields,
            customSections: custom_sections,
            deletedSections: deleted_sections,
            history: history,
            isEmpty: is_empty,
            emptyState: is_empty ? empty_state_metadata : nil
          }
        end

        # POST /api/v1/admin/forms/:form_name/reset
        def reset
          # Revert to the baseline seeded record from the database
          default_seeded = FormConfiguration.where(form_type: @form_config.form_type, is_default: true)
                                            .where.not(id: @form_config.id)
                                            .first ||
                           FormConfiguration.where(form_type: @form_config.form_type).first

          reset_schema = if default_seeded && default_seeded.field_schema.present?
                           default_seeded.field_schema.deep_dup
                         else
                           empty_field_schema
                         end

          @form_config.update!(
            field_schema: reset_schema,
            is_default: true,
            revision_date: Date.current
          )

          is_empty = (reset_schema["fields"] || []).empty?

          render json: {
            status: "ok",
            formName: @form_config.form_name,
            formType: @form_config.form_type,
            fields: reset_schema["fields"] || [],
            isEmpty: is_empty,
            emptyState: is_empty ? empty_state_metadata : nil
          }
        end

        private

        def set_form_config
          name = URI.decode_www_form_component(params[:form_name].to_s).strip

          # Map user-friendly form names to form_type enum
          type = case name.downcase
          when /enroll/ then :enrollment
          when /iup/ then :iup
          when /ablls/ then :ablls
          when /incident/ then :abc_data_sheet
          when /behavior/ then :behavioral_assessment
          when /sensory/ then :sensory
          when /preference/ then :preference_assessment
          when /data record|task analysis/ then :task_analysis
          when /social/ then :social_skills
          else :enrollment
          end

          # Retrieve directly from the database (seeded by db/seeds/02_admin_configuration.rb)
          @form_config = FormConfiguration.find_by("lower(form_name) = ?", name.downcase) ||
                         FormConfiguration.where(form_type: type).order(is_default: :desc, id: :asc).first ||
                         FormConfiguration.find_or_initialize_by(form_name: name) do |fc|
                           fc.form_type = type
                           fc.is_default = true
                           fc.revision_number = 1
                           fc.revision_date = Date.current
                           fc.field_schema = empty_field_schema
                         end
        end

        def empty_field_schema
          {
            "fields" => [],
            "customSections" => [],
            "deletedSections" => [],
            "history" => []
          }
        end

        def empty_state_metadata(form_name = nil)
          title_name = form_name || @form_config&.form_name || "Form"
          {
            "title" => "#{title_name}: No Fields Configured",
            "message" => "This form has no active fields yet. Add questions and sections in Form Builder to start collecting clinical data.",
            "action" => "add_field"
          }
        end
      end
    end
  end
end
