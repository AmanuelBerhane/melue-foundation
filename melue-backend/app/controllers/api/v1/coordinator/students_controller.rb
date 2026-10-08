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

          rows = students.map do |s|
            age = s.date_of_birth ? (Date.current.year - s.date_of_birth.year) : 0
            assignment = s.teacher_student_assignments.first
            therapist_name = assignment&.teacher&.full_name || "Unassigned"

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

          first_name = raw_params[:first_name] || raw_params[:firstName]
          last_name = raw_params[:last_name] || raw_params[:lastName] || "Unknown"
          dob = raw_params[:date_of_birth] || raw_params[:dateOfBirth] || "2018-01-01"

          # Normalize program type to valid Rails enum: regular or pulled_out
          raw_program = (raw_params[:program_type] || raw_params[:programType]).to_s.downcase
          program_type = raw_program.include?("pull") ? :pulled_out : :regular

          # Normalize therapy group to valid Rails enum: basic or functional_living
          raw_group = (raw_params[:therapy_group] || raw_params[:therapyGroup]).to_s.downcase
          therapy_group = raw_group.include?("function") ? :functional_living : :basic

          service_params = {
            first_name: first_name,
            middle_name: raw_params[:middle_name] || raw_params[:middleName],
            last_name: last_name,
            date_of_birth: dob,
            program_type: program_type,
            therapy_group: therapy_group,
            status: :in_assessment,
            diagnosis: raw_params[:diagnosis].presence || "Autism Spectrum Disorder",
            guardian_name: raw_params[:guardian_name] || raw_params[:parentName].presence || "Guardian",
            guardian_phone: raw_params[:guardian_phone] || raw_params[:parentPhone].presence || "555-0100",
            guardian_email: raw_params[:guardian_email] || raw_params[:parentEmail],
            headshot: raw_params[:headshot] || raw_params[:photo],
            custom_fields: custom_fields,
            enrolled_at: Time.current
          }

          result = ::Students::RegisterService.call(params: service_params, current_user: current_user)

          if result.success?
            student = result.data

            if raw_params[:assignedTherapist].present?
              assign_therapist(student, raw_params[:assignedTherapist])
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
          therapist_name = assignment&.teacher&.full_name || "Unassigned"
          age = @student.date_of_birth ? (Date.current.year - @student.date_of_birth.year) : 0

          birth_cert = @student.documents.find_by(document_type: "birth_certificate")
          diag_paper = @student.documents.find_by(document_type: "diagnosis_paper")
          agreement = @student.documents.find_by(document_type: "agreement")

          documents_list = @student.documents.map do |doc|
            serialize_document(doc)
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
          attrs[:first_name] = params[:firstName] if params[:firstName].present?
          attrs[:first_name] = params[:first_name] if params[:first_name].present?
          attrs[:last_name] = params[:lastName] if params[:lastName].present?
          attrs[:last_name] = params[:last_name] if params[:last_name].present?
          attrs[:diagnosis] = params[:diagnosis] if params[:diagnosis].present?
          attrs[:guardian_name] = params[:guardianName] if params[:guardianName].present?
          attrs[:guardian_name] = params[:guardian_name] if params[:guardian_name].present?
          attrs[:guardian_phone] = params[:guardianPhone] if params[:guardianPhone].present?
          attrs[:guardian_phone] = params[:guardian_phone] if params[:guardian_phone].present?
          attrs[:guardian_email] = params[:guardianEmail] if params[:guardianEmail].present?
          attrs[:guardian_email] = params[:guardian_email] if params[:guardian_email].present?

          custom_f = params[:custom_fields] || params[:customFields]
          attrs[:custom_fields] = parse_custom_fields(custom_f) if custom_f.present?

          if @student.update(attrs)
            render json: { success: true, student: @student }
          else
            render json: { errors: @student.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_student
          lookup = (params[:id] || params[:student_id] || params[:studentId]).to_s.strip
          @student = if lookup.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
            Student.find_by(id: lookup)
          else
            Student.find_by("student_id ILIKE ?", lookup) || Student.find_by(id: lookup)
          end
          render json: { error: "Student not found" }, status: :not_found unless @student
        end

        def create_params
          params.permit(
            :firstName, :first_name,
            :lastName, :last_name,
            :middleName, :middle_name,
            :dateOfBirth, :date_of_birth,
            :programType, :program_type,
            :therapyGroup, :therapy_group,
            :diagnosis,
            :studentId, :student_id,
            :parentName, :guardian_name,
            :parentPhone, :guardian_phone,
            :parentEmail, :guardian_email,
            :assignedTherapist,
            :headshot, :photo,
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
          staff = StaffMember.find_by("full_name ILIKE ?", "%#{therapist_param.strip}%") || StaffMember.first
          return unless staff

          station = TherapyStation.first
          room = TherapyRoom.first
          block = SessionBlockDefinition.first
          return unless station && room && block

          TeacherStudentAssignment.create(
            student: student,
            teacher: staff,
            therapy_station: station,
            therapy_room: room,
            session_block_definition: block,
            scheduled_date: Date.current,
            status: "scheduled"
          )
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
            url: file_url,
            file_url: file_url,
            byte_size: file&.byte_size,
            content_type: file&.content_type,
            description: doc.description,
            created_at: doc.created_at
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
