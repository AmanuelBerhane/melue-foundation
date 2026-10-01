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
            students = students.where("first_name ILIKE :q OR last_name ILIKE :q", q: query)
          end

          rows = students.map do |s|
            age = s.date_of_birth ? (Date.current.year - s.date_of_birth.year) : 0
            assignment = s.teacher_student_assignments.first
            therapist_name = assignment&.teacher&.full_name || "Unassigned"

            {
              id: s.id.to_s,
              fullName: "#{s.first_name} #{s.last_name}".strip,
              firstName: s.first_name,
              lastName: s.last_name,
              age: age,
              programType: s.program_type.to_s.humanize,
              therapyGroup: s.therapy_group.to_s.humanize,
              therapist: therapist_name,
              diagnosis: s.diagnosis.presence || "Autism Spectrum Disorder",
              status: s.status.to_s.downcase.include?("active") ? "active" : "inactive",
              studentId: s.id.to_s,
              enrolledAt: s.enrolled_at || s.created_at
            }
          end

          render json: rows
        end

        # POST /api/v1/coordinator/students
        def create
          first_name = params[:firstName] || params[:first_name]
          last_name = params[:lastName] || params[:last_name] || "Unknown"
          dob = params[:dateOfBirth] || params[:date_of_birth] || "2018-01-01"

          # Normalize program type to valid Rails enum: regular or pulled_out
          raw_program = params[:programType].to_s.downcase
          program_type = raw_program.include?("pull") ? :pulled_out : :regular

          # Normalize therapy group to valid Rails enum: basic or functional_living
          raw_group = params[:therapyGroup].to_s.downcase
          therapy_group = raw_group.include?("function") ? :functional_living : :basic

          student = Student.new(
            first_name: first_name,
            last_name: last_name,
            date_of_birth: dob,
            program_type: program_type,
            therapy_group: therapy_group,
            status: :registered,
            diagnosis: params[:diagnosis].presence || "Autism Spectrum Disorder",
            guardian_name: params[:parentName].presence || params[:guardian_name].presence || "Guardian",
            guardian_phone: params[:parentPhone].presence || params[:guardian_phone].presence || "555-0100",
            guardian_email: params[:parentEmail].presence || params[:guardian_email],
            enrolled_at: Time.current
          )

          if student.save
            # If therapist assigned, link assignment if possible
            if params[:assignedTherapist].present?
              staff = StaffMember.find_by("full_name ILIKE ?", "%#{params[:assignedTherapist].strip}%") || StaffMember.first
              if staff
                station = TherapyStation.first
                room = TherapyRoom.first
                block = SessionBlockDefinition.first
                if station && room && block
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
              end
            end

            render json: {
              id: student.id.to_s,
              fullName: "#{student.first_name} #{student.last_name}".strip,
              program: student.program_type.to_s.humanize,
              status: "Registered"
            }, status: :created
          else
            render json: { errors: student.errors.full_messages }, status: :unprocessable_entity
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

          render json: {
            id: @student.id.to_s,
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
            enrolledAt: @student.enrolled_at
          }
        end

        # PATCH /api/v1/coordinator/students/:id/profile
        def update_profile
          attrs = {}
          attrs[:first_name] = params[:firstName] if params[:firstName].present?
          attrs[:last_name] = params[:lastName] if params[:lastName].present?
          attrs[:diagnosis] = params[:diagnosis] if params[:diagnosis].present?
          attrs[:guardian_name] = params[:guardianName] if params[:guardianName].present?
          attrs[:guardian_phone] = params[:guardianPhone] if params[:guardianPhone].present?
          attrs[:guardian_email] = params[:guardianEmail] if params[:guardianEmail].present?

          if @student.update(attrs)
            render json: { success: true, student: @student }
          else
            render json: { errors: @student.errors.full_messages }, status: :unprocessable_entity
          end
        end

        private

        def set_student
          @student = Student.find(params[:id] || params[:student_id])
        end
      end
    end
  end
end
