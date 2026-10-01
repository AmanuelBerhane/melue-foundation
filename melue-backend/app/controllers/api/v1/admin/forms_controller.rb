# frozen_string_literal: true

module Api
  module V1
    module Admin
      class FormsController < BaseController
        before_action :authenticate_user!
        before_action :set_form_config

        # GET /api/v1/admin/forms/:form_name
        def show
          schema = @form_config.field_schema || {}
          fields = schema["fields"] || []

          # If empty, populate with standard defaults
          if fields.empty?
            schema = default_schema_for(@form_config.form_type)
            @form_config.update!(field_schema: schema)
          end

          render json: {
            formName: @form_config.form_name,
            formType: @form_config.form_type,
            revisionNumber: @form_config.revision_number,
            isDefault: @form_config.is_default,
            fields: schema["fields"] || [],
            customSections: schema["customSections"] || schema["sections"] || [],
            deletedSections: schema["deletedSections"] || [],
            history: schema["history"] || []
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
            history: history
          }
        end

        # POST /api/v1/admin/forms/:form_name/reset
        def reset
          default_schema = default_schema_for(@form_config.form_type)
          @form_config.update!(
            field_schema: default_schema,
            is_default: true,
            revision_date: Date.current
          )

          render json: { status: "ok" }
        end

        private

        def set_form_config
          name = URI.decode_www_form_component(params[:form_name].to_s).strip

          # Map user-friendly form names to form_type enum
          type = case name.downcase
          when /enrollment/ then :enrollment
          when /iup/ then :iup
          when /ablls|skills/ then :ablls
          else :enrollment
          end

          @form_config = FormConfiguration.find_or_create_by!(form_type: type) do |fc|
            fc.form_name = name
            fc.is_default = true
            fc.revision_number = 1
            fc.field_schema = default_schema_for(type)
          end
        end

        def default_schema_for(type)
          case type.to_s
          when "enrollment"
            {
              "fields" => [
                { "id" => "f1", "type" => "text", "label" => "Full Name", "required" => true, "visible" => true, "section" => "Student Info" },
                { "id" => "f2", "type" => "date", "label" => "Date of Birth", "required" => true, "visible" => true, "section" => "Student Info" },
                { "id" => "f4", "type" => "text", "label" => "Parent / Guardian Name", "required" => true, "visible" => true, "section" => "Parent Info" },
                { "id" => "f5", "type" => "text", "label" => "Parent Phone", "required" => true, "visible" => true, "section" => "Parent Info" },
                { "id" => "f6", "type" => "text", "label" => "Parent Email", "required" => true, "visible" => true, "section" => "Parent Info" },
                { "id" => "f7", "type" => "textarea", "label" => "Medical Notes & Allergies", "required" => false, "visible" => true, "section" => "Medical Info" },
                { "id" => "f8", "type" => "checkbox", "label" => "Transportation Required", "required" => false, "visible" => true, "section" => "Medical Info" },
                { "id" => "f9", "type" => "text", "label" => "Emergency Contact", "required" => false, "visible" => true, "section" => "Parent Info" }
              ],
              "customSections" => [],
              "deletedSections" => [],
              "history" => []
            }
          when "iup"
            {
              "fields" => [
                { "id" => "i1", "type" => "text", "label" => "Student Name", "required" => true, "visible" => true },
                { "id" => "i2", "type" => "dropdown", "label" => "Target Skill Domain", "required" => true, "visible" => true, "options" => [ "Language & Communication", "Social Interaction", "Adaptive & Self-Care", "Motor Skills", "Cognitive" ] },
                { "id" => "i3", "type" => "number", "label" => "Baseline Mastery (%)", "required" => true, "visible" => true },
                { "id" => "i4", "type" => "textarea", "label" => "Target Objective", "required" => true, "visible" => true }
              ],
              "customSections" => [],
              "deletedSections" => [],
              "history" => []
            }
          else # ablls
            {
              "fields" => [
                { "id" => "A1", "type" => "radio", "label" => "A1: Matches identical objects", "required" => true, "visible" => true, "section" => "Visual Performance", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Mastered", "N/A" ] },
                { "id" => "A2", "type" => "radio", "label" => "A2: Matches identical pictures to objects", "required" => true, "visible" => true, "section" => "Visual Performance", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Mastered", "N/A" ] },
                { "id" => "B1", "type" => "radio", "label" => "B1: Gross motor imitation", "required" => true, "visible" => true, "section" => "Motor Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Mastered", "N/A" ] },
                { "id" => "C1", "type" => "radio", "label" => "C1: Imitation of vowel sounds", "required" => true, "visible" => true, "section" => "Vocal Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Mastered", "N/A" ] }
              ],
              "customSections" => [],
              "deletedSections" => [],
              "history" => []
            }
          end
        end
      end
    end
  end
end
