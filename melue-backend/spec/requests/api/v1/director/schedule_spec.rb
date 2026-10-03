# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Director::Schedule", type: :request do
  let(:headers) { director_headers }
  let!(:config) { create(:session_schedule_config, staff_to_student_capacity: 2) }
  let(:station) { create(:therapy_station) }
  let(:room) { create(:therapy_room, therapy_station: station) }
  let(:block) { create(:session_block_definition) }
  let(:teacher) { create(:staff_member, role: "teacher") }
  let(:other_teacher) { create(:staff_member, role: "teacher") }
  let(:student) { create(:student, status: "active_therapy") }

  def assign(student_id:, teacher_id: teacher.id, block_id: block.id, extra: {})
    post "/api/v1/director/schedule/assign",
         params: { teacherId: teacher_id, studentId: student_id, blockId: block_id, roomId: room.id }.merge(extra),
         headers: headers, as: :json
  end

  describe "POST /api/v1/director/schedule/assign" do
    it "creates the assignment and returns the capacity indicator (FR-119)" do
      expect { assign(student_id: student.id) }.to change(TeacherStudentAssignment, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["data"]).to include("teacherId" => teacher.id, "studentId" => student.id,
                                      "blockId" => block.id, "roomId" => room.id, "stationId" => station.id)
      expect(body["capacity"]).to eq("current" => 1, "max" => 2)
    end

    it "enforces the configured capacity limit (FR-118)" do
      create_list(:teacher_student_assignment, 2, teacher: teacher, session_block_definition: block)

      expect { assign(student_id: student.id) }.not_to change(TeacherStudentAssignment, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to include("code" => "capacity_exceeded")
      expect(response.parsed_body["error"]).to include("capacity limit of 2")
    end

    it "ignores cancelled assignments when counting capacity" do
      create_list(:teacher_student_assignment, 2, teacher: teacher, session_block_definition: block, status: "cancelled")

      assign(student_id: student.id)
      expect(response).to have_http_status(:created)
    end

    it "rejects double-booking a student to another teacher in the same block (FR-120)" do
      create(:teacher_student_assignment, teacher: other_teacher, student: student, session_block_definition: block)

      expect { assign(student_id: student.id) }.not_to change(TeacherStudentAssignment, :count)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to include("code" => "double_booking",
                                              "conflicting_teacher_id" => other_teacher.id,
                                              "conflicting_teacher_name" => other_teacher.full_name)
    end

    it "allows the same student in a different block" do
      create(:teacher_student_assignment, teacher: other_teacher, student: student,
                                          session_block_definition: create(:session_block_definition, :afternoon))

      assign(student_id: student.id)
      expect(response).to have_http_status(:created)
    end

    it "revives a previously cancelled row instead of violating the unique index" do
      cancelled = create(:teacher_student_assignment, teacher: other_teacher, student: student,
                                                      session_block_definition: block, status: "cancelled")

      expect { assign(student_id: student.id) }.not_to change(TeacherStudentAssignment, :count)
      expect(response).to have_http_status(:created)
      expect(cancelled.reload).to have_attributes(teacher_id: teacher.id, status: "scheduled")
    end

    it "rejects assignments to an unavailable teacher (FR-122)" do
      create(:staff_availability, staff_member: teacher, unavailable_date: Date.current, session_block_definition: nil)

      assign(student_id: student.id)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["code"]).to eq("teacher_unavailable")
    end

    it "returns 404 for an unknown student" do
      assign(student_id: SecureRandom.uuid)
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["code"]).to eq("student_not_found")
    end

    it "returns 400 for an invalid date" do
      assign(student_id: student.id, extra: { date: "not-a-date" })
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 403 for a teacher" do
      post "/api/v1/director/schedule/assign",
           params: { teacherId: teacher.id, studentId: student.id, blockId: block.id },
           headers: teacher_headers, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/director/schedule/assignments (bulk)" do
    it "rejects students that would exceed capacity" do
      students = create_list(:student, 3, status: "active_therapy")
      room # ensure a station/room exists for the default location

      post "/api/v1/director/schedule/assignments",
           params: { teacherId: teacher.id, blockId: block.id, studentIds: students.map(&:id) },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].map { |e| e["code"] }).to eq([ "capacity_exceeded" ])
      expect(TeacherStudentAssignment.where(teacher: teacher).count).to eq(2)
    end
  end

  describe "POST /api/v1/director/schedule/blocks/:block_id/clear" do
    let(:path) { "/api/v1/director/schedule/blocks/#{block.id}/clear" }

    it "deletes the block's assignment records for the date" do
      create_list(:teacher_student_assignment, 2, teacher: teacher, session_block_definition: block)
      other_day = create(:teacher_student_assignment, teacher: teacher, session_block_definition: block,
                                                      scheduled_date: Date.tomorrow)

      expect { post path, headers: headers, as: :json }.to change(TeacherStudentAssignment, :count).by(-2)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("status" => "ok", "removed_count" => 2)
      expect(TeacherStudentAssignment.exists?(other_day.id)).to be(true)
    end

    it "can be narrowed to one teacher and specific students" do
      keep = create(:teacher_student_assignment, teacher: other_teacher, session_block_definition: block)
      target = create(:teacher_student_assignment, teacher: teacher, session_block_definition: block)
      untouched = create(:teacher_student_assignment, teacher: teacher, session_block_definition: block)

      post path, params: { teacherId: teacher.id, studentIds: [ target.student_id ] }, headers: headers, as: :json

      expect(response.parsed_body["removed_student_ids"]).to eq([ target.student_id ])
      expect(TeacherStudentAssignment.where(id: [ keep.id, untouched.id ]).count).to eq(2)
    end

    it "frees the slot so the student can be re-assigned" do
      create(:teacher_student_assignment, teacher: other_teacher, student: student, session_block_definition: block)
      post path, headers: headers, as: :json

      assign(student_id: student.id)
      expect(response).to have_http_status(:created)
    end

    it "keeps assignments that already have a started session and reports them" do
      assignment = create(:teacher_student_assignment, teacher: teacher, session_block_definition: block)
      create(:session_participant, teacher_student_assignment: assignment, student: assignment.student)

      expect { post path, headers: headers, as: :json }.not_to change(TeacherStudentAssignment, :count)
      expect(response.parsed_body["skipped"].first).to include("assignment_id" => assignment.id)
    end

    it "returns 404 for an unknown block" do
      post "/api/v1/director/schedule/blocks/#{SecureRandom.uuid}/clear", headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "returns 400 instead of clearing today when the date is invalid" do
      create(:teacher_student_assignment, teacher: teacher, session_block_definition: block)

      expect { post path, params: { date: "bad" }, headers: headers, as: :json }
        .not_to change(TeacherStudentAssignment, :count)
      expect(response).to have_http_status(:bad_request)
    end
  end
end
