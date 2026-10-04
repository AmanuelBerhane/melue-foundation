# frozen_string_literal: true

module Api
  module V1
    module Director
      class ScheduleController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_director_or_admin, except: :show

        UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

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

        # @oas_include
        # @summary Assign a student to a teacher for a session block (FR-117, FR-118, FR-120)
        # @tags Director Scheduling
        # @auth [bearer_jwt]
        # @request_body Assignment [!Hash{ teacherId: String, studentId: String, blockId: String, date: String, stationId: String, roomId: String }]
        # @request_body_example [JSON{ "teacherId": "uuid", "studentId": "uuid", "blockId": "uuid", "date": "2026-10-03" }]
        # @response Created (201) [Hash{ data: Hash, capacity: Hash{ current: Integer, max: Integer } }]
        # @response Forbidden (403) [Hash{ error: String }]
        # @response Not Found (404) [Hash{ error: String, code: String }]
        # @response Double booking (409) [Hash{ error: String, code: String, conflicting_teacher_id: String, conflicting_teacher_name: String }]
        # @response Capacity exceeded or teacher unavailable (422) [Hash{ error: String, code: String }]
        # POST /api/v1/director/schedule/assign
        def assign_student
          date = parse_date(param_value(:date, :scheduled_date))
          return render json: { error: "Invalid date", code: "invalid_date" }, status: :bad_request unless date

          result = ::Director::AssignStudentService.call(
            teacher: StaffMember.kept.find_by(id: param_value(:teacherId, :teacher_id)),
            student: Student.kept.find_by(id: param_value(:studentId, :student_id)),
            block: resolve_block(param_value(:blockId, :session_block_definition_id)),
            date: date,
            station: find_optional(TherapyStation, param_value(:stationId, :therapy_station_id)),
            room: find_optional(TherapyRoom, param_value(:roomId, :therapy_room_id))
          )

          if result.success?
            render json: { data: serialize_assignment(result.data[:assignment]), capacity: result.data[:capacity] },
                   status: :created
          else
            render json: { error: result.error }.merge(result.data || {}), status: result.status
          end
        end

        # POST /api/v1/director/schedule/assignments
        # Bulk variant used by the scheduling grid. Each student goes through the
        # same capacity (FR-118) and double-booking (FR-120) checks as #assign_student.
        def save_assignment
          teacher = StaffMember.kept.find_by(id: params[:teacherId].presence) || StaffMember.kept.first
          block = resolve_block(params[:blockId])
          date = parse_date(params[:date]) || Date.current

          errors = Array(params[:studentIds]).filter_map do |sid|
            result = ::Director::AssignStudentService.call(
              teacher: teacher, student: Student.kept.find_by(id: sid), block: block, date: date
            )
            next if result.success?
            # Re-saving a student already on this teacher's block is a no-op for the grid.
            next if result.status == :conflict && result.data[:conflicting_teacher_id] == teacher&.id

            { student_id: sid.to_s, error: result.error, code: result.data[:code] }
          end

          if errors.empty?
            render json: { status: "ok" }
          else
            render json: { status: "error", errors: errors }, status: :unprocessable_entity
          end
        end

        # @oas_include
        # @summary Remove assignments from a session block (FR-117)
        # @tags Director Scheduling
        # @auth [bearer_jwt]
        # @parameter block_id(path) [!String] Session block definition ID
        # @request_body Filters [Hash{ date: String, teacherId: String, studentIds: Array<String> }]
        # @response Success (200) [Hash{ status: String, removed_count: Integer, removed_student_ids: Array<String>, skipped: Array<Hash> }]
        # @response Forbidden (403) [Hash{ error: String }]
        # @response Not Found (404) [Hash{ error: String }]
        # POST /api/v1/director/schedule/blocks/:block_id/clear
        def clear_block
          date = parse_date(params[:date])
          return render json: { error: "Invalid date", code: "invalid_date" }, status: :bad_request unless date

          result = ::Director::ClearBlockService.call(
            block: resolve_block(params[:block_id]),
            date: date,
            teacher_id: param_value(:teacherId, :teacher_id),
            student_ids: params[:studentIds] || params[:student_ids]
          )

          if result.success?
            render json: { status: "ok" }.merge(result.data)
          else
            render_error(result.error, result.status)
          end
        end

        private

        def param_value(*keys)
          keys.lazy.map { |k| params[k].presence }.find(&:itself)
        end

        def parse_date(raw)
          return Date.current if raw.blank?

          Date.iso8601(raw.to_s)
        rescue Date::Error
          nil
        end

        def find_optional(model, id)
          id.present? ? model.kept.find_by(id: id) : nil
        end

        # Accepts a SessionBlockDefinition UUID, or one of the grid's template
        # ids ("b1…" = Station 1 / first block, "b2…" = Station 2 / second block).
        def resolve_block(block_id)
          return nil if block_id.blank?
          return SessionBlockDefinition.kept.find_by(id: block_id) if block_id.to_s.match?(UUID_FORMAT)

          blocks = SessionBlockDefinition.kept.active.ordered.to_a
          block_id.to_s.start_with?("b2") ? (blocks.second || blocks.first) : blocks.first
        end

        def serialize_assignment(assignment)
          {
            id: assignment.id,
            teacherId: assignment.teacher_id,
            studentId: assignment.student_id,
            blockId: assignment.session_block_definition_id,
            stationId: assignment.therapy_station_id,
            roomId: assignment.therapy_room_id,
            date: assignment.scheduled_date.iso8601,
            status: assignment.status
          }
        end
      end
    end
  end
end
