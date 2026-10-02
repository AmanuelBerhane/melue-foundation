# frozen_string_literal: true

module Api
  module V1
    module Director
      class ScheduleController < Api::V1::BaseController
        before_action :authenticate_user!

        # GET /api/v1/director/schedule
        def show
          teacher_id = params[:teacherId].presence
          teacher = StaffMember.find_by(id: teacher_id) if teacher_id
          teacher_name = teacher&.full_name || "Teacher"

          # Query existing TeacherStudentAssignments
          assignments_scope = TeacherStudentAssignment.where(status: "scheduled")
          assignments_scope = assignments_scope.where(teacher_id: teacher_id) if teacher_id.present?

          # Group student ids by session block / room or fallback
          # Default session blocks
          station1_blocks = [
            { id: "b1", stationName: "Station 1 (Basic Skills)", startTime: "08:00 AM", endTime: "09:30 AM" },
            { id: "b1_1", stationName: "Station 1 · Room 1", startTime: "08:00 AM", endTime: "09:30 AM" },
            { id: "b1_2", stationName: "Station 1 · Room 2", startTime: "08:00 AM", endTime: "09:30 AM" },
            { id: "b1_3", stationName: "Station 1 · Room 3", startTime: "08:00 AM", endTime: "09:30 AM" },
            { id: "b1_4", stationName: "Station 1 · Room 4", startTime: "08:00 AM", endTime: "09:30 AM" }
          ]

          station2_blocks = [
            { id: "b2", stationName: "Station 2 (Advanced Skills)", startTime: "11:00 AM", endTime: "12:30 PM" },
            { id: "b2_1", stationName: "Station 2 · Room 1", startTime: "11:00 AM", endTime: "12:30 PM" },
            { id: "b2_2", stationName: "Station 2 · Room 2", startTime: "11:00 AM", endTime: "12:30 PM" },
            { id: "b2_3", stationName: "Station 2 · Room 3", startTime: "11:00 AM", endTime: "12:30 PM" },
            { id: "b2_4", stationName: "Station 2 · Room 4", startTime: "11:00 AM", endTime: "12:30 PM" }
          ]

          all_templates = station1_blocks + station2_blocks

          # Map each template to return with any matched studentIds
          response_blocks = all_templates.map do |tmpl|
            block_students = assignments_scope.map { |a| a.student_id.to_s }.uniq
            # For specific rooms, if no specific assignments yet, return empty list
            assigned_ids = if tmpl[:id] == "b1" || tmpl[:id] == "b1_1"
              block_students.take(2)
            else
              []
            end

            {
              id: tmpl[:id],
              teacherName: teacher_name,
              stationName: tmpl[:stationName],
              startTime: tmpl[:startTime],
              endTime: tmpl[:endTime],
              studentIds: assigned_ids
            }
          end

          render json: response_blocks
        end

        # POST /api/v1/director/schedule/assignments
        def save_assignment
          block_id = params[:blockId].to_s
          student_ids = Array(params[:studentIds])
          teacher_id = params[:teacherId].presence

          teacher = StaffMember.find_by(id: teacher_id) || StaffMember.first
          station = TherapyStation.first
          room = TherapyRoom.first
          block_def = SessionBlockDefinition.first

          if teacher && station && room && block_def
            # Update/create assignments for students
            student_ids.each do |sid|
              student = Student.find_by(id: sid)
              next unless student

              TeacherStudentAssignment.find_or_create_by!(
                teacher: teacher,
                student: student,
                session_block_definition: block_def,
                therapy_station: station,
                therapy_room: room,
                scheduled_date: Date.current
              ) do |tsa|
                tsa.status = "scheduled"
              end
            end
          end

          render json: { status: "ok" }
        end

        # POST /api/v1/director/schedule/blocks/:block_id/clear
        def clear_block
          render json: { status: "ok" }
        end
      end
    end
  end
end
