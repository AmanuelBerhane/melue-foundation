# frozen_string_literal: true

module Api
  module V1
    module Admin
      class FormsController < BaseController
        before_action :authenticate_user!
        before_action :set_form_config, except: [ :index ]

        # GET /api/v1/admin/forms
        def index
          configs = FormConfiguration.all.order(:form_name)
          is_empty = configs.empty?

          render json: {
            forms: configs.map do |fc|
              schema = fc.field_schema || empty_field_schema
              fields = schema["fields"] || []
              meta = (schema["metadata"] || {}).stringify_keys
              form_id = meta["form_id"] || meta["formId"] || default_form_id_for(fc.form_type)
              org_name = fc.organization_name.presence || meta["organization"] || meta["organization_name"] || meta["organizationName"] || "Melu-e Center"
              rev_num = fc.revision_number || meta["revision_number"] || meta["revisionNumber"] || 1
              rev_date = fc.revision_date&.to_s || meta["revision_date"] || meta["revisionDate"] || Date.current.to_s
              rev_str = meta["revision"] || "Rev #{rev_num}.0 · #{rev_date}"
              pages_str = meta["pages"] || "Page 1 of 1"

              {
                id: fc.id,
                formName: fc.form_name,
                form_name: fc.form_name,
                formType: fc.form_type,
                revisionNumber: rev_num,
                revision_number: rev_num,
                revisionDate: rev_date,
                revision_date: rev_date,
                organizationName: org_name,
                organization_name: org_name,
                organization: org_name,
                formId: form_id,
                form_id: form_id,
                revision: rev_str,
                pages: pages_str,
                metadata: meta.merge({
                  "form_id" => form_id,
                  "formId" => form_id,
                  "form_name" => fc.form_name,
                  "formName" => fc.form_name,
                  "organization" => org_name,
                  "organization_name" => org_name,
                  "organizationName" => org_name,
                  "revision" => rev_str,
                  "revision_number" => rev_num,
                  "revisionNumber" => rev_num,
                  "revision_date" => rev_date,
                  "revisionDate" => rev_date,
                  "pages" => pages_str
                }),
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
          meta = (schema["metadata"] || {}).stringify_keys

          form_id = meta["form_id"] || meta["formId"] || default_form_id_for(@form_config.form_type)
          form_name = @form_config.form_name.presence || meta["form_name"] || meta["formName"]
          org_name = @form_config.organization_name.presence || meta["organization"] || meta["organization_name"] || meta["organizationName"] || "Melu-e Center"
          rev_num = @form_config.revision_number || meta["revision_number"] || meta["revisionNumber"] || 1
          rev_date = @form_config.revision_date&.to_s || meta["revision_date"] || meta["revisionDate"] || Date.current.to_s
          rev_str = meta["revision"] || "Rev #{rev_num}.0 · #{rev_date}"
          pages_str = meta["pages"] || "Page 1 of 1"

          full_metadata = meta.merge({
            "form_id" => form_id,
            "formId" => form_id,
            "form_name" => form_name,
            "formName" => form_name,
            "organization" => org_name,
            "organization_name" => org_name,
            "organizationName" => org_name,
            "revision" => rev_str,
            "revision_number" => rev_num,
            "revisionNumber" => rev_num,
            "revision_date" => rev_date,
            "revisionDate" => rev_date,
            "pages" => pages_str
          })

          render json: {
            id: @form_config.id,
            formName: form_name,
            form_name: form_name,
            formType: @form_config.form_type,
            revisionNumber: rev_num,
            revision_number: rev_num,
            revisionDate: rev_date,
            revision_date: rev_date,
            organizationName: org_name,
            organization_name: org_name,
            organization: org_name,
            formId: form_id,
            form_id: form_id,
            revision: rev_str,
            pages: pages_str,
            metadata: full_metadata,
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

          # 1. Previous state from existing @form_config
          prev_schema = (@form_config.field_schema || {}).deep_dup
          prev_fields = prev_schema["fields"] || []
          prev_custom_sections = prev_schema["customSections"] || prev_schema["sections"] || []
          prev_deleted_sections = prev_schema["deletedSections"] || []
          prev_history = prev_schema["history"] || []
          prev_meta = (prev_schema["metadata"] || {}).stringify_keys

          prev_form_name = @form_config.form_name.presence || prev_meta["form_name"] || prev_meta["formName"]
          prev_form_id = prev_meta["form_id"] || prev_meta["formId"] || default_form_id_for(@form_config.form_type)
          prev_org = @form_config.organization_name.presence || prev_meta["organization"] || prev_meta["organization_name"] || prev_meta["organizationName"] || "Melu-e Center"
          prev_rev_num = @form_config.revision_number || prev_meta["revision_number"] || prev_meta["revisionNumber"] || 1
          prev_rev_date = @form_config.revision_date&.to_s || prev_meta["revision_date"] || prev_meta["revisionDate"] || Date.current.to_s
          prev_rev_str = prev_meta["revision"] || "Rev #{prev_rev_num}.0 · #{prev_rev_date}"
          prev_pages = prev_meta["pages"] || "Page 1 of 1"

          # 2. Extract incoming values from payload and nested metadata
          incoming_meta = (payload["metadata"].is_a?(Hash) ? payload["metadata"] : {}).stringify_keys
          incoming_form_name = payload["form_name"] || payload["formName"] || incoming_meta["form_name"] || incoming_meta["formName"]
          incoming_form_id = payload["form_id"] || payload["formId"] || incoming_meta["form_id"] || incoming_meta["formId"]
          incoming_org = payload["organization_name"] || payload["organizationName"] || payload["organization"] || incoming_meta["organization_name"] || incoming_meta["organizationName"] || incoming_meta["organization"]
          incoming_pages = payload["pages"] || incoming_meta["pages"]
          incoming_rev_str = payload["revision"] || incoming_meta["revision"]
          incoming_rev_num = payload["revision_number"] || payload["revisionNumber"] || incoming_meta["revision_number"] || incoming_meta["revisionNumber"]
          incoming_rev_date = payload["revision_date"] || payload["revisionDate"] || incoming_meta["revision_date"] || incoming_meta["revisionDate"]

          # 3. Detect changes
          header_changed = false
          header_changed ||= (incoming_form_name.present? && incoming_form_name.to_s.strip != prev_form_name.to_s.strip)
          header_changed ||= (incoming_form_id.present? && incoming_form_id.to_s.strip != prev_form_id.to_s.strip)
          header_changed ||= (incoming_org.present? && incoming_org.to_s.strip != prev_org.to_s.strip)
          header_changed ||= (incoming_pages.present? && incoming_pages.to_s.strip != prev_pages.to_s.strip)
          header_changed ||= (incoming_rev_date.present? && incoming_rev_date.to_s.strip != prev_rev_date.to_s.strip)
          header_changed ||= (incoming_rev_str.present? && incoming_rev_str.to_s.strip != prev_rev_str.to_s.strip)
          header_changed ||= (incoming_rev_num.present? && incoming_rev_num.to_i != prev_rev_num.to_i)

          user_changed_version = false
          if incoming_rev_num.present? && incoming_rev_num.to_i != prev_rev_num.to_i
            user_changed_version = true
          elsif incoming_rev_str.present? && incoming_rev_str.to_s.strip != prev_rev_str.to_s.strip
            user_changed_version = true
          end

          # 4. Preserve Body Components Across Header Edits
          raw_fields = if payload.key?("fields")
            p_fields = payload["fields"]
            if (p_fields.nil? || p_fields.empty?) && prev_fields.present? && header_changed
              prev_fields
            else
              p_fields || []
            end
          else
            prev_fields
          end

          seen_ids = Set.new
          fields = raw_fields.map.with_index do |f, idx|
            fh = f.is_a?(Hash) ? f.deep_dup : {}
            f_id = fh["id"].presence || "f_#{idx + 1}_#{SecureRandom.hex(3)}"
            f_id = "#{f_id}_#{idx + 1}" if seen_ids.include?(f_id)
            seen_ids.add(f_id)
            fh["id"] = f_id
            fh["type"] = fh["type"].presence || fh["field_type"].presence || "Text"
            fh
          end

          custom_sections = if payload.key?("customSections")
            payload["customSections"]
          elsif payload.key?("sections")
            payload["sections"]
          else
            prev_custom_sections
          end || []

          deleted_sections = if payload.key?("deletedSections")
            payload["deletedSections"]
          else
            prev_deleted_sections
          end || []

          body_changed = (fields != prev_fields) || (custom_sections != prev_custom_sections) || (deleted_sections != prev_deleted_sections)

          # 5. Semantic Version Increment
          new_rev_num = if user_changed_version && incoming_rev_num.present?
            incoming_rev_num.to_i
          elsif user_changed_version && incoming_rev_str.present?
            parsed = incoming_rev_str[/Rev\s+(\d+)/i, 1] || incoming_rev_str[/v(\d+)/i, 1]
            parsed ? parsed.to_i : (prev_rev_num + 1)
          else
            # Automatically increment revision_number for the newly saved record
            prev_rev_num + 1
          end

          new_rev_date = incoming_rev_date.presence || Date.current.to_s
          new_rev_str = if user_changed_version && incoming_rev_str.present?
            incoming_rev_str
          else
            "Rev #{new_rev_num}.0 · #{new_rev_date}"
          end

          new_form_name = incoming_form_name.presence || prev_form_name
          new_form_id = incoming_form_id.presence || prev_form_id
          new_org = incoming_org.presence || prev_org
          new_pages = incoming_pages.presence || prev_pages

          # 6. Immutable Snapshot Versioning Workflow
          base_history = if payload.key?("history") && payload["history"].is_a?(Array)
            payload["history"].deep_dup
          else
            prev_history.deep_dup
          end

          if (header_changed || body_changed) && (prev_fields.present? || prev_meta.present?)
            snapshot = {
              "id" => "snap_#{prev_rev_num}_#{SecureRandom.hex(4)}",
              "version" => "v#{prev_rev_num}.0",
              "versionNumber" => "v#{prev_rev_num}.0",
              "revision_number" => prev_rev_num,
              "revisionNumber" => prev_rev_num,
              "revision" => prev_rev_str,
              "revision_date" => prev_rev_date,
              "revisionDate" => prev_rev_date,
              "form_id" => prev_form_id,
              "formId" => prev_form_id,
              "form_name" => prev_form_name,
              "formName" => prev_form_name,
              "organization_name" => prev_org,
              "organizationName" => prev_org,
              "organization" => prev_org,
              "pages" => prev_pages,
              "metadata" => prev_meta.merge({
                "form_id" => prev_form_id,
                "formId" => prev_form_id,
                "form_name" => prev_form_name,
                "formName" => prev_form_name,
                "revision" => prev_rev_str,
                "revision_number" => prev_rev_num,
                "revisionNumber" => prev_rev_num,
                "revision_date" => prev_rev_date,
                "revisionDate" => prev_rev_date,
                "organization" => prev_org,
                "organization_name" => prev_org,
                "organizationName" => prev_org,
                "pages" => prev_pages
              }),
              "fields" => prev_fields,
              "customSections" => prev_custom_sections,
              "deletedSections" => prev_deleted_sections,
              "date" => prev_rev_date,
              "user" => Current.user&.email || "Institutional Admin",
              "author" => Current.user&.email || "Institutional Admin",
              "field" => header_changed ? "Form Header & Metadata" : "Form Canvas Components",
              "oldValue" => "Rev #{prev_rev_num}.0",
              "newValue" => "Rev #{new_rev_num}.0",
              "created_at" => Time.current.iso8601,
              "saved_at" => Time.current.iso8601
            }
            base_history = [snapshot] + base_history
          end

          # 7. Persist to FormConfiguration
          updated_meta = incoming_meta.merge({
            "form_id" => new_form_id,
            "formId" => new_form_id,
            "form_name" => new_form_name,
            "formName" => new_form_name,
            "organization" => new_org,
            "organization_name" => new_org,
            "organizationName" => new_org,
            "revision" => new_rev_str,
            "revision_number" => new_rev_num,
            "revisionNumber" => new_rev_num,
            "revision_date" => new_rev_date,
            "revisionDate" => new_rev_date,
            "pages" => new_pages
          })

          new_schema = {
            "fields" => fields,
            "customSections" => custom_sections,
            "deletedSections" => deleted_sections,
            "history" => base_history,
            "metadata" => updated_meta
          }

          @form_config.form_name = new_form_name if new_form_name.present?
          @form_config.organization_name = new_org if new_org.present?
          @form_config.revision_number = new_rev_num
          @form_config.revision_date = (Date.parse(new_rev_date) rescue Date.current)
          @form_config.field_schema = new_schema
          @form_config.is_default = payload["isDefault"] == true
          @form_config.save!

          is_empty = fields.empty?

          render json: {
            id: @form_config.id,
            formName: @form_config.form_name,
            form_name: @form_config.form_name,
            formType: @form_config.form_type,
            revisionNumber: @form_config.revision_number,
            revision_number: @form_config.revision_number,
            revisionDate: @form_config.revision_date&.to_s,
            revision_date: @form_config.revision_date&.to_s,
            organizationName: @form_config.organization_name,
            organization_name: @form_config.organization_name,
            organization: @form_config.organization_name,
            formId: updated_meta["formId"],
            form_id: updated_meta["formId"],
            revision: updated_meta["revision"],
            pages: updated_meta["pages"],
            metadata: updated_meta,
            isDefault: @form_config.is_default,
            fields: fields,
            customSections: custom_sections,
            deletedSections: deleted_sections,
            history: base_history,
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
            form_name: @form_config.form_name,
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
                           fc.organization_name = "Melu-e Center"
                           fc.field_schema = empty_field_schema
                         end
        end

        def default_form_id_for(form_type)
          case form_type.to_s
          when "enrollment" then "FRM-ENR-001"
          when "iup" then "FRM-IUP-001"
          when "ablls" then "FRM-ABLLS-001"
          when "abc_data_sheet" then "FRM-ABC-001"
          when "behavioral_assessment" then "FRM-BEH-001"
          when "preference_assessment" then "FRM-PREF-001"
          when "sensory" then "FRM-SEN-001"
          when "social_skills" then "FRM-SOC-001"
          when "task_analysis" then "FRM-TA-001"
          else "FRM-SYS-001"
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
