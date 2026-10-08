# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Director::Dashboard", type: :request do
  let(:path) { "/api/v1/director/dashboard" }

  describe "GET /api/v1/director/dashboard" do
    context "as a Director" do
      let(:headers) { director_headers }

      before do
        create(:session_schedule_config, staff_to_student_capacity: 3)
        active_students = create_list(:student, 3, status: "active_therapy")
        create(:student, status: "in_assessment")

        teacher = create(:staff_member, role: "teacher")
        create(:staff_member, role: "teacher")
        block = create(:session_block_definition)
        assignment = create(:teacher_student_assignment, teacher: teacher, student: active_students.first,
                                                         session_block_definition: block)

        session = create(:therapy_session, teacher: teacher, session_block_definition: block)
        create(:session_participant, therapy_session: session, student: active_students.first,
                                     teacher_student_assignment: assignment)
        create(:session_summary, therapy_session: session, status: "submitted", submitted_at: Time.current)
      end

      it "returns live operational counts" do
        get path, headers: headers

        expect(response).to have_http_status(:ok)
        data = response.parsed_body["data"]

        expect(data["students"]).to include("total_active" => 3, "in_assessment" => 1)
        expect(data["staff"]).to include("teachers_on_duty" => 1)
        expect(data["staff"]["total_teachers"]).to be >= 2
        expect(data["sessions"]).to include("in_progress" => 1, "students_in_session" => 1, "rooms_in_use" => 1)
        expect(data["scheduling"]).to include("assignments_today" => 1, "students_scheduled_today" => 1,
                                              "unassigned_active_students" => 2, "capacity_per_teacher" => 3)
        expect(data["reviews"]["session_summaries_pending_review"]).to eq(1)
        expect(data).to include("generated_at", "activity")
      end
    end

    it "allows institutional admins" do
      get path, headers: institutional_admin_headers
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 for a teacher" do
      get path, headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["error"]).to match(/Director or Administrator/)
    end

    it "returns 401 without a token" do
      get path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
