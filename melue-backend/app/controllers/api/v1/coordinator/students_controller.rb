# frozen_string_literal: true

module Api
  module V1
    module Coordinator
      class StudentsController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :set_student, only: %i[show profile update_profile]

        # GET /api/v1/coordinator/students
        def index
          students = Student.all.order(created_at: :desc)

          if params[:search].present?
            query = "%#{params[:search].strip}%"
            students = students.where("first_name ILIKE :q OR last_name ILIKE :q OR student_id ILIKE :q", q: query)
          end

          if params[:student_id].present? || params[:studentId].present?
            sid = "%#{(params[:student_id] || params[:studentId]).to_s.strip}%"
            students = students.where("student_id ILIKE :sid", sid: sid)
          end

          if params[:program].present? && params[:program] != "All"
            prog = params[:program].to_s.downcase
            if prog.include?("pull")
              students = students.where(program_type: :pulled_out)
            elsif prog.include?("regular")
              students = students.where(program_type: :regular)
            end
          end

          if (params[:therapy_group].present? || params[:therapyGroup].present?) && (params[:therapy_group] || params[:therapyGroup]) != "All"
            tg = (params[:therapy_group] || params[:therapyGroup]).to_s.downcase
            if tg.include?("function")
              students = students.where(therapy_group: :functional_living)
            elsif tg.include?("basic")
              students = students.where(therapy_group: :basic)
            end
          end

          if params[:status].present? && params[:status] != "All"
            st = params[:status].to_s.downcase
            if st == "active"
              students = students.where(status: [ :active, :active_therapy, :registered, :ready_for_iup, :in_assessment, :assessment_complete ])
            elsif st == "inactive"
              students = students.where(status: :inactive)
            elsif st == "draft"
              students = students.where(status: [ :draft, :pending_review ])
            elsif st == "archived"
              students = students.where(status: [ :archived, :discharged, :withdrawn ])
            end
          end

          if (params[:therapy_status].present? || params[:therapyStatus].present?) && (params[:therapy_status] || params[:therapyStatus]) != "All"
            ts = (params[:therapy_status] || params[:therapyStatus]).to_s.downcase.tr(" ", "_")
            if ts == "in_assessment" || ts == "assessment"
              students = students.where(status: :in_assessment)
            elsif ts == "assessment_complete" || ts == "assessment_completed"
              students = students.where(status: :assessment_complete)
            elsif ts == "ready_for_iup"
              students = students.where(status: :ready_for_iup)
            elsif ts == "iup_ready"
              students = students.where(status: [ :ready_for_iup, :active_therapy, :active ])
            elsif ts == "in_session" || ts == "active_therapy" || ts == "active"
              students = students.where(status: [ :active_therapy, :active ])
            elsif ts == "not_started" || ts == "registered" || ts == "enrolled"
              students = students.where(status: [ :registered, :draft, :pending_review ])
            elsif ts == "draft"
              students = students.where(status: [ :draft, :pending_review ])
            else
              students = students.where(status: ts)
            end
          end

          rows = students.map do |s|
            age = s.date_of_birth ? (Date.current.year - s.date_of_birth.year) : 0
            assignment = s.teacher_student_assignments.first
            custom_therapist = s.custom_fields.is_a?(Hash) ? (s.custom_fields["f_therapist"] || s.custom_fields["therapist"] || s.custom_fields["assigned_therapist"]) : nil
            therapist_name = assignment&.teacher&.full_name || custom_therapist || "Unassigned"

            display_therapy_status = case s.status.to_s
            when "in_assessment" then "In Assessment"
            when "assessment_complete" then "Assessment Complete"
            when "ready_for_iup" then "Ready for IUP"
            when "active_therapy", "active" then "In Session"
            when "draft", "pending_review", "registered" then "Not Started"
            when "withdrawn" then "Withdrawn"
            when "discharged" then "Discharged"
            when "archived" then "Archived"
            else s.status.to_s.humanize.titleize
            end

            {
              id: s.id.to_s,
              studentId: s.student_id,
              student_id: s.student_id,
              fullName: "#{s.first_name} #{s.last_name}".strip,
              firstName: s.first_name,
              lastName: s.last_name,
              age: age,
              programType: s.program_type.to_s.humanize,
              therapyGroup: s.therapy_group.to_s.humanize,
              therapist: therapist_name,
              diagnosis: s.diagnosis.presence || "Autism Spectrum Disorder",
              status: s.status.to_s.downcase.include?("active") ? "active" : "inactive",
              raw_status: s.status.to_s,
              rawStatus: s.status.to_s,
              therapy_status: display_therapy_status,
              therapyStatus: display_therapy_status,
              enrolledAt: s.enrolled_at || s.created_at,
              custom_fields: s.custom_fields || {},
              customFields: s.custom_fields || {}
            }
          end

          render json: rows
        end

        # POST /api/v1/coordinator/students
        def create
          raw_params = create_params
          custom_fields = parse_custom_fields(params[:custom_fields] || params[:customFields] || raw_params[:custom_fields] || raw_params[:customFields])

          first_name = raw_params[:first_name].presence ||
                       raw_params[:firstName].presence ||
                       raw_params[:childFirstName].presence ||
                       raw_params[:child_first_name].presence ||
                       raw_params[:enr_first_name].presence ||
                       custom_fields[:first_name].presence ||
                       custom_fields["first_name"].presence ||
                       custom_fields[:firstName].presence ||
                       custom_fields["firstName"].presence ||
                       custom_fields[:childFirstName].presence ||
                       custom_fields["childFirstName"].presence ||
                       custom_fields[:child_first_name].presence ||
                       custom_fields["child_first_name"].presence ||
                       custom_fields[:enr_first_name].presence ||
                       custom_fields["enr_first_name"].presence ||
                       custom_fields[:f1].presence ||
                       custom_fields["f1"].presence

          if first_name.blank? && (raw_params[:fullName].present? || raw_params[:full_name].present? || raw_params[:name].present? || params[:name].present? || params[:fullName].present?)
            full = raw_params[:fullName] || raw_params[:full_name] || raw_params[:name] || params[:name] || params[:fullName]
            first_name = full.to_s.strip.split.first
          end
          first_name ||= "Student"

          last_name = raw_params[:last_name].presence ||
                      raw_params[:lastName].presence ||
                      raw_params[:childLastName].presence ||
                      raw_params[:child_last_name].presence ||
                      raw_params[:enr_last_name].presence ||
                      custom_fields[:last_name].presence ||
                      custom_fields["last_name"].presence ||
                      custom_fields[:lastName].presence ||
                      custom_fields["lastName"].presence ||
                      custom_fields[:childLastName].presence ||
                      custom_fields["childLastName"].presence ||
                      custom_fields[:child_last_name].presence ||
                      custom_fields["child_last_name"].presence ||
                      custom_fields[:enr_last_name].presence ||
                      custom_fields["enr_last_name"].presence

          if last_name.blank? && (raw_params[:fullName].present? || raw_params[:full_name].present? || raw_params[:name].present? || params[:name].present? || params[:fullName].present?)
            full = raw_params[:fullName] || raw_params[:full_name] || raw_params[:name] || params[:name] || params[:fullName]
            rest = full.to_s.strip.split[1..]
            last_name = rest.join(" ") if rest.present?
          end
          last_name ||= "Unknown"

          dob = raw_params[:date_of_birth] || raw_params[:dateOfBirth] || raw_params[:dob] || raw_params[:enr_dob] || "2018-01-01"

          # Normalize program type to valid Rails enum: regular or pulled_out
          raw_program = (raw_params[:program_type] || raw_params[:programType] || raw_params[:program] || raw_params[:enr_program_type]).to_s.downcase
          program_type = raw_program.include?("pull") ? :pulled_out : :regular

          # Normalize therapy group to valid Rails enum: basic or functional_living
          raw_group = (raw_params[:therapy_group] || raw_params[:therapyGroup] || raw_params[:enr_therapy_group]).to_s.downcase
          therapy_group = raw_group.include?("function") ? :functional_living : :basic

          service_params = {
            first_name: first_name,
            middle_name: raw_params[:middle_name] || raw_params[:middleName] || raw_params[:childMiddleName] || raw_params[:child_middle_name] || raw_params[:enr_middle_name],
            last_name: last_name,
            date_of_birth: dob,
            program_type: program_type,
            therapy_group: therapy_group,
            status: :in_assessment,
            diagnosis: raw_params[:diagnosis].presence || "Autism Spectrum Disorder",
            guardian_name: raw_params[:guardian_name] || raw_params[:parentName].presence || raw_params[:enr_guardian_name].presence || "Guardian",
            guardian_phone: raw_params[:guardian_phone] || raw_params[:parentPhone].presence || raw_params[:enr_guardian_phone].presence || "555-0100",
            headshot: raw_params[:headshot] || raw_params[:photo] || raw_params[:enr_headshot] || raw_params[:photoUrl] || raw_params[:photo_url],
            baseline_video: raw_params[:baseline_video] || raw_params[:baselineVideo] || raw_params[:enr_baseline_video] || raw_params[:video] || raw_params[:videoUrl],
            birth_certificate: raw_params[:birth_certificate] || raw_params[:birthCertificate] || raw_params[:enr_birth_certificate],
            diagnosis_paper: raw_params[:diagnosis_paper] || raw_params[:diagnosisPaper] || raw_params[:enr_diagnosis_paper],
            agreement: raw_params[:agreement] || raw_params[:agreement_document] || raw_params[:agreementDocument] || raw_params[:enr_agreement],
            custom_fields: custom_fields,
            enrolled_at: Time.current
          }

          result = ::Students::RegisterService.call(params: service_params, current_user: current_user)

          if result.success?
            student = result.data

            if raw_params[:assignedTherapist].present?
              assign_therapist(student, raw_params[:assignedTherapist])
            end

            # Ensure assessment cycle is initialized for 6-week baseline assessment
            if student.status == "in_assessment"
              AssessmentCycle.find_or_create_by!(student: student, status: "in_progress") do |c|
                c.started_on = Date.current
              end
            end

            render json: {
              id: student.id.to_s,
              studentId: student.student_id,
              student_id: student.student_id,
              fullName: "#{student.first_name} #{student.last_name}".strip,
              program: student.program_type.to_s.humanize,
              status: student.status.to_s.humanize,
              custom_fields: student.custom_fields || {},
              customFields: student.custom_fields || {}
            }, status: :created
          else
            render json: { errors: [ result.error ] }, status: :unprocessable_content
          end
        end

        # GET /api/v1/coordinator/students/:id
        def show
          profile
        end

        # GET /api/v1/coordinator/students/:id/profile
        def profile
          assignment = @student.teacher_student_assignments.first
          custom_therapist = @student.custom_fields.is_a?(Hash) ? (@student.custom_fields["f_therapist"] || @student.custom_fields["therapist"] || @student.custom_fields["assigned_therapist"]) : nil
          therapist_name = assignment&.teacher&.full_name || custom_therapist || "Unassigned"
          age = @student.date_of_birth ? (Date.current.year - @student.date_of_birth.year) : 0

          birth_cert = @student.documents.find_by(document_type: "birth_certificate")
          diag_paper = @student.documents.find_by(document_type: "diagnosis_paper")
          agreement = @student.documents.find_by(document_type: "agreement")

          documents_list = @student.documents.map do |doc|
            serialize_document(doc)
          end

          goals_list = @student.student_goals.map do |g|
            {
              id: g.id.to_s,
              name: g.goal_name || "Goal",
              status: g.status || "in_progress",
              progressPercent: g.progress_percent || 0
            }
          end

          render json: {
            id: @student.id.to_s,
            studentId: @student.student_id,
            student_id: @student.student_id,
            fullName: "#{@student.first_name} #{@student.last_name}".strip,
            firstName: @student.first_name,
            lastName: @student.last_name,
            dateOfBirth: @student.date_of_birth,
            age: age,
            programType: @student.program_type.to_s.humanize,
            therapyGroup: @student.therapy_group.to_s.humanize,
            status: @student.status.to_s.humanize,
            diagnosis: @student.diagnosis,
            therapist: therapist_name,
            guardianName: @student.guardian_name,
            guardianPhone: @student.guardian_phone,
            guardianEmail: @student.guardian_email,
            enrolledAt: @student.enrolled_at,
            custom_fields: @student.custom_fields || {},
            customFields: @student.custom_fields || {},
            goals: goals_list,
            documents: documents_list,
            birth_certificate: serialize_document(birth_cert),
            birthCertificate: serialize_document(birth_cert),
            diagnosis_paper: serialize_document(diag_paper),
            diagnosisPaper: serialize_document(diag_paper),
            agreement: serialize_document(agreement),
            hasPhoto: @student.headshot_photo.attached? || @student.headshot.attached?,
            photoUrl: student_photo_url(@student),
            photo_url: student_photo_url(@student),
            hasVideo: @student.baseline_video.attached?,
            videoUrl: student_video_url(@student),
            video_url: student_video_url(@student)
          }
        end

        # PATCH /api/v1/coordinator/students/:id/profile
        def update_profile
          attrs = {}
          fn = params[:firstName] || params[:first_name] || params[:childFirstName] || params[:child_first_name] || params[:enr_first_name]
          attrs[:first_name] = fn if fn.present?

          ln = params[:lastName] || params[:last_name] || params[:childLastName] || params[:child_last_name] || params[:enr_last_name]
          attrs[:last_name] = ln if ln.present?

          mn = params[:middleName] || params[:middle_name] || params[:childMiddleName] || params[:child_middle_name] || params[:enr_middle_name]
          attrs[:middle_name] = mn if mn.present?

          if attrs[:first_name].blank? && (params[:fullName].present? || params[:name].present?)
            full = params[:fullName] || params[:name]
            attrs[:first_name] = full.to_s.strip.split.first
          end

          dob = params[:dateOfBirth] || params[:date_of_birth] || params[:dob] || params[:enr_dob]
          attrs[:date_of_birth] = dob if dob.present?

          raw_prog = (params[:programType] || params[:program_type] || params[:program] || params[:enr_program_type]).to_s.downcase
          if raw_prog.present?
            attrs[:program_type] = raw_prog.include?("pull") ? :pulled_out : :regular
          end

          raw_grp = (params[:therapyGroup] || params[:therapy_group] || params[:enr_therapy_group]).to_s.downcase
          if raw_grp.present?
            attrs[:therapy_group] = raw_grp.include?("function") ? :functional_living : :basic
          end

          raw_st = (params[:status] || params[:enrollment_status]).to_s.downcase
          if raw_st.present?
            if raw_st.include?("assessment")
              attrs[:status] = :in_assessment
            elsif raw_st.include?("active")
              attrs[:status] = :active
            elsif raw_st.include?("draft")
              attrs[:status] = :draft
            elsif raw_st.include?("inactive")
              attrs[:status] = :inactive
            end
          end

          attrs[:diagnosis] = params[:diagnosis] if params[:diagnosis].present?
          attrs[:guardian_name] = params[:guardianName] || params[:guardian_name] || params[:parentName] || params[:enr_guardian_name] if (params[:guardianName] || params[:guardian_name] || params[:parentName] || params[:enr_guardian_name]).present?
          attrs[:guardian_phone] = params[:guardianPhone] || params[:guardian_phone] || params[:parentPhone] || params[:enr_guardian_phone] if (params[:guardianPhone] || params[:guardian_phone] || params[:parentPhone] || params[:enr_guardian_phone]).present?
          attrs[:guardian_email] = params[:guardianEmail] || params[:guardian_email] || params[:parentEmail] || params[:enr_guardian_email] if (params[:guardianEmail] || params[:guardian_email] || params[:parentEmail] || params[:enr_guardian_email]).present?

          therapist_param = params[:therapist] || params[:assignedTherapist] || params[:f_therapist]

          # If student was not found in DB by set_student, register them on-the-fly
          if @student.nil?
            service_params = {
              first_name: fn.presence || "Student",
              middle_name: mn,
              last_name: ln.presence || "Unknown",
              date_of_birth: dob.presence || "2018-01-01",
              program_type: attrs[:program_type] || :regular,
              therapy_group: attrs[:therapy_group] || :basic,
              status: attrs[:status] || :in_assessment,
              diagnosis: attrs[:diagnosis].presence || "Autism Spectrum Disorder",
              guardian_name: attrs[:guardian_name].presence || "Guardian",
              guardian_phone: attrs[:guardian_phone].presence || "555-0100",
              guardian_email: attrs[:guardian_email],
              custom_fields: parse_custom_fields(params[:custom_fields] || params[:customFields]),
              enrolled_at: Time.current
            }
            reg_res = ::Students::RegisterService.call(params: service_params, current_user: current_user)
            if reg_res.success?
              @student = reg_res.data
            else
              render json: { error: "Student not found and could not be registered: #{reg_res.error}" }, status: :not_found and return
            end
          end

          if therapist_param.present?
            assign_therapist(@student, therapist_param)
          end

          if params[:remove_headshot].present? || params[:delete_headshot].present?
            @student.headshot.purge if @student.headshot.attached?
            @student.headshot_photo.purge if @student.headshot_photo.attached?
          end

          if params[:remove_baseline_video].present? || params[:delete_baseline_video].present?
            @student.baseline_video.purge if @student.baseline_video.attached?
          end

          %w[birth_certificate diagnosis_paper agreement other].each do |dtype|
            if params["remove_#{dtype}"].present? || params["delete_#{dtype}"].present?
              @student.documents.where(document_type: dtype).destroy_all
            end
          end

          if params[:delete_document_id].present?
            @student.documents.where(id: params[:delete_document_id]).destroy_all
          end

          if (params[:headshot] || params[:photo] || params[:enr_headshot] || params[:photoUrl] || params[:photo_url]).present?
            file = params[:headshot] || params[:photo] || params[:enr_headshot] || params[:photoUrl] || params[:photo_url]
            attach_active_storage_file(@student.headshot, file, "headshot.jpg", "image/jpeg")
            attach_active_storage_file(@student.headshot_photo, file, "headshot.jpg", "image/jpeg")
          end

          if (params[:baseline_video] || params[:baselineVideo] || params[:enr_baseline_video] || params[:video] || params[:videoUrl]).present?
            file = params[:baseline_video] || params[:baselineVideo] || params[:enr_baseline_video] || params[:video] || params[:videoUrl]
            attach_active_storage_file(@student.baseline_video, file, "baseline_video.mp4", "video/mp4")
          end

          if (params[:birth_certificate] || params[:birthCertificate] || params[:enr_birth_certificate]).present?
            file = params[:birth_certificate] || params[:birthCertificate] || params[:enr_birth_certificate]
            attach_student_doc(@student, "birth_certificate", file, "birth_certificate.pdf", "application/pdf")
          end

          if (params[:diagnosis_paper] || params[:diagnosisPaper] || params[:enr_diagnosis_paper]).present?
            file = params[:diagnosis_paper] || params[:diagnosisPaper] || params[:enr_diagnosis_paper]
            attach_student_doc(@student, "diagnosis_paper", file, "diagnosis_paper.pdf", "application/pdf")
          end

          if (params[:agreement] || params[:agreement_document] || params[:agreementDocument] || params[:enr_agreement]).present?
            file = params[:agreement] || params[:agreement_document] || params[:agreementDocument] || params[:enr_agreement]
            attach_student_doc(@student, "agreement", file, "agreement.pdf", "application/pdf")
          end

          custom_f = params[:custom_fields] || params[:customFields]
          attrs[:custom_fields] = parse_custom_fields(custom_f) if custom_f.present?

          if @student.update(attrs)
            render json: {
              success: true,
              student: @student,
              data: {
                id: @student.id.to_s,
                studentId: @student.student_id,
                student_id: @student.student_id,
                fullName: "#{@student.first_name} #{@student.last_name}".strip,
                firstName: @student.first_name,
                lastName: @student.last_name,
                dateOfBirth: @student.date_of_birth,
                programType: @student.program_type.to_s.humanize,
                therapyGroup: @student.therapy_group.to_s.humanize,
                status: @student.status.to_s.humanize,
                diagnosis: @student.diagnosis,
                custom_fields: @student.custom_fields || {}
              }
            }
          else
            render json: { errors: @student.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def attach_active_storage_file(attachment, file, default_filename, default_content_type)
          target = build_file_io(file, default_filename: default_filename, default_content_type: default_content_type)
          return unless target.present?

          blob = target.is_a?(ActiveStorage::Blob) ? target : ActiveStorage::Blob.create_and_upload!(
            io: target[:io],
            filename: target[:filename],
            content_type: target[:content_type]
          )
          attachment.attach(blob)
        rescue => e
          Rails.logger.warn("Attachment error: #{e.message}")
        end

        def attach_student_doc(student, doc_type, file, default_filename, default_content_type)
          target = build_file_io(file, default_filename: default_filename, default_content_type: default_content_type)
          return unless target.present?

          blob = target.is_a?(ActiveStorage::Blob) ? target : ActiveStorage::Blob.create_and_upload!(
            io: target[:io],
            filename: target[:filename],
            content_type: target[:content_type]
          )
          doc = student.documents.find_or_initialize_by(document_type: doc_type)
          doc.file.attach(blob)
          doc.description ||= "#{doc_type.humanize} attached"
          doc.save!
        rescue => e
          Rails.logger.warn("Document attachment error: #{e.message}")
        end

        def build_file_io(file, default_filename:, default_content_type:)
          return nil unless file.present?

          if file.is_a?(ActiveStorage::Blob)
            file
          elsif file.is_a?(String) && file.start_with?("data:")
            match = file.match(/\Adata:([^;]+);base64,(.+)\z/m)
            if match
              content_type = match[1]
              data = Base64.decode64(match[2])
              ext = Rack::Mime::MIME_TYPES.invert[content_type] || ".bin"
              filename = default_filename.end_with?(ext) ? default_filename : "#{File.basename(default_filename, '.*')}#{ext}"
              { io: StringIO.new(data), filename: filename, content_type: content_type }
            else
              nil
            end
          elsif file.respond_to?(:read) || file.respond_to?(:tempfile)
            {
              io: file.respond_to?(:tempfile) ? file.tempfile : file,
              filename: file.respond_to?(:original_filename) ? file.original_filename : default_filename,
              content_type: file.respond_to?(:content_type) ? file.content_type : default_content_type
            }
          elsif file.is_a?(Hash) && file[:io].present?
            file
          else
            nil
          end
        end

        def set_student
          lookup = (params[:id] || params[:student_id] || params[:studentId]).to_s.strip
          is_uuid = lookup.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
          @student = if is_uuid
            Student.find_by(id: lookup) || Student.find_by("student_id ILIKE ?", lookup)
          else
            Student.find_by("student_id ILIKE ?", lookup) ||
            Student.find_by("CONCAT(first_name, ' ', last_name) ILIKE ?", lookup) ||
            Student.find_by("first_name ILIKE :q OR last_name ILIKE :q", q: lookup)
          end

          if @student.nil? && params[:studentId].present? && params[:studentId].to_s.strip != lookup
            @student = Student.find_by("student_id ILIKE ?", params[:studentId].to_s.strip)
          end

          if @student.nil? && params[:student_id].present? && params[:student_id].to_s.strip != lookup
            @student = Student.find_by("student_id ILIKE ?", params[:student_id].to_s.strip)
          end

          if @student.nil? && (params[:fullName].present? || params[:name].present?)
            full = (params[:fullName] || params[:name]).to_s.strip
            @student = Student.find_by("CONCAT(first_name, ' ', last_name) ILIKE ?", full) ||
                       Student.find_by("first_name ILIKE :q OR last_name ILIKE :q", q: full.split.first)
          end

          if @student.nil? && lookup.present?
            @student = Student.where("custom_fields::text ILIKE ?", "%#{lookup}%").first
          end

          # For update_profile, do not halt immediately so update_profile can register on-the-fly if needed
          if @student.nil? && action_name != "update_profile"
            render json: { error: "Student not found" }, status: :not_found
          end
        end

        def create_params
          params.permit(
            :firstName, :first_name, :childFirstName, :child_first_name, :enr_first_name,
            :lastName, :last_name, :childLastName, :child_last_name, :enr_last_name,
            :middleName, :middle_name, :childMiddleName, :child_middle_name, :enr_middle_name,
            :fullName, :full_name, :name,
            :dateOfBirth, :date_of_birth, :dob, :enr_dob,
            :programType, :program_type, :program, :enr_program_type,
            :therapyGroup, :therapy_group, :therapy_group_track, :enr_therapy_group,
            :diagnosis, :enr_diagnosis,
            :diagnosisDate, :diagnosis_date, :enr_diagnosis_date,
            :studentId, :student_id,
            :parentName, :guardian_name, :enr_guardian_name,
            :parentPhone, :guardian_phone, :enr_guardian_phone,
            :parentEmail, :guardian_email, :enr_guardian_email,
            :emergencyContact, :emergency_contact, :enr_emergency_contact,
            :assignedTherapist, :therapist,
            :headshot, :photo, :enr_headshot, :photoUrl, :photo_url,
            :birth_certificate, :birthCertificate, :enr_birth_certificate,
            :diagnosis_paper, :diagnosisPaper, :enr_diagnosis_paper,
            :agreement, :agreement_document, :agreementDocument, :enr_agreement,
            :baseline_video, :baselineVideo, :enr_baseline_video, :video, :videoUrl, :video_url,
            custom_fields: {},
            customFields: {}
          )
        end

        def parse_custom_fields(fields)
          return {} if fields.blank?

          if fields.is_a?(String)
            begin
              JSON.parse(fields)
            rescue JSON::ParserError
              {}
            end
          elsif fields.respond_to?(:to_unsafe_h)
            fields.to_unsafe_h
          elsif fields.is_a?(Hash)
            fields
          else
            {}
          end
        end

        def assign_therapist(student, therapist_param)
          return unless therapist_param.present?

          clean_param = therapist_param.to_s.strip
          # 1. Try direct ID
          staff = StaffMember.find_by(id: clean_param)
          # 2. Try exact / partial full_name
          staff ||= StaffMember.find_by("full_name ILIKE ?", "%#{clean_param}%")

          # 3. Normalize digit representations: "Teacher 2" <-> "Teacher Two"
          num_to_word = { "1" => "One", "2" => "Two", "3" => "Three", "4" => "Four", "5" => "Five" }
          word_to_num = { "one" => "1", "two" => "2", "three" => "3", "four" => "4", "five" => "5" }

          word_converted = clean_param
          num_to_word.each { |num, word| word_converted = word_converted.gsub(/\b#{num}\b/, word) }
          staff ||= StaffMember.find_by("full_name ILIKE ?", "%#{word_converted}%")

          num_converted = clean_param.downcase
          word_to_num.each { |word, num| num_converted = num_converted.gsub(/\b#{word}\b/, num) }
          staff ||= StaffMember.find_by("full_name ILIKE ?", "%#{num_converted}%")

          # 4. Try user email lookup
          staff ||= User.find_by("email ILIKE ?", "%#{clean_param}%")&.staff_member

          # 5. Safe fallback to an active teacher, never an admin
          staff ||= StaffMember.where(role: :teacher).first || StaffMember.first
          return unless staff

          station = TherapyStation.first
          room = TherapyRoom.first
          block = SessionBlockDefinition.first
          return unless station && room && block

          # Avoid duplicate assignments
          existing = TeacherStudentAssignment.find_by(student: student, teacher: staff)
          return existing if existing.present?

          TeacherStudentAssignment.create!(
            student: student,
            teacher: staff,
            therapy_station: station,
            therapy_room: room,
            session_block_definition: block,
            scheduled_date: Date.current,
            status: "scheduled"
          )
        rescue => e
          Rails.logger.warn("assign_therapist warning: #{e.message}")
        end

        def serialize_document(doc)
          return nil unless doc

          file = doc.file if doc.file.attached?
          file_url = file ? url_for(file) : nil

          {
            id: doc.id,
            document_type: doc.document_type,
            documentType: doc.document_type,
            type: doc.document_type,
            filename: file&.filename&.to_s,
            fileName: file&.filename&.to_s,
            name: file&.filename&.to_s,
            url: file_url,
            file_url: file_url,
            fileUrl: file_url,
            byte_size: file&.byte_size,
            byteSize: file&.byte_size,
            file_size: file&.byte_size,
            content_type: file&.content_type,
            contentType: file&.content_type,
            description: doc.description,
            created_at: doc.created_at,
            upload_date: doc.created_at&.strftime("%b %d, %Y"),
            uploadDate: doc.created_at&.strftime("%b %d, %Y")
          }
        end

        def student_photo_url(student)
          att = student.headshot_photo.attached? ? student.headshot_photo : student.headshot
          return nil unless att&.attached?

          url_for(att)
        end

        def student_video_url(student)
          return nil unless student.baseline_video.attached?

          url_for(student.baseline_video)
        end
      end
    end
  end
end
