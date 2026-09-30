# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::TherapyCoordinator::OperationalManagement", type: :request do
  let(:coordinator_user) { create(:user, :clinical_staff) }
  let(:coordinator_headers) { authenticated_headers(coordinator_user) }

  let(:non_coordinator_user) { create(:user, :therapist) }
  let(:non_coordinator_headers) { authenticated_headers(non_coordinator_user) }

  let!(:teacher1) { create(:staff_member, full_name: "Teacher Alice", role: "teacher") }
  let!(:teacher2) { create(:staff_member, full_name: "Teacher Bob", role: "teacher") }
  let(:station) { create(:therapy_station) }
  let(:room) { create(:therapy_room, therapy_station: station) }

  let!(:morning_block) do
    create(:session_block_definition,
           name: "Morning Round 1",
           round: "morning",
           start_time: Time.zone.parse("09:00:00"),
           end_time: Time.zone.parse("11:30:00"),
           is_active: true)
  end

  let!(:afternoon_block) do
    create(:session_block_definition,
           name: "Afternoon Round 1",
           round: "afternoon",
           start_time: Time.zone.parse("13:00:00"),
           end_time: Time.zone.parse("15:30:00"),
           is_active: true)
  end

  let(:student1) { create(:student, status: "active_therapy") }
  let!(:student2) { create(:student, status: "active_therapy") }
  let(:date) { Date.current }

  let!(:assignment1) do
    create(:teacher_student_assignment,
           teacher: teacher1,
           student: student1,
           session_block_definition: morning_block,
           therapy_station: station,
           therapy_room: room,
           scheduled_date: date,
           status: "scheduled")
  end

  describe "GET /api/v1/therapy_coordinator/operational_management (FR-121)" do
    context "when authorized as therapy coordinator" do
      it "returns 200 with operational overview screen data" do
        get "/api/v1/therapy_coordinator/operational_management",
            params: { date: date.to_s },
            headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body

        expect(body["summary"]).to be_present
        expect(body["summary"]["total_teachers"]).to be >= 2
        expect(body["blocks"]).to be_an(Array)
        expect(body["teachers"]).to be_an(Array)
        expect(body["unassigned_alerts"]).to be_an(Array)
      end
    end

    context "when unauthorized" do
      it "returns 403 forbidden" do
        get "/api/v1/therapy_coordinator/operational_management", headers: non_coordinator_headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/therapy_coordinator/operational_management/reassign (FR-123)" do
    context "when reassigning a student to an available teacher" do
      it "reassigns the assignment successfully" do
        post "/api/v1/therapy_coordinator/operational_management/reassign",
             params: {
               assignment_id: assignment1.id,
               new_teacher_id: teacher2.id
             },
             headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["reassigned_count"]).to eq(1)
        expect(assignment1.reload.teacher_id).to eq(teacher2.id)
      end
    end

    context "when target teacher is unavailable" do
      before do
        create(:staff_availability,
               staff_member: teacher2,
               unavailable_date: date,
               session_block_definition: morning_block,
               reason: "Dentist appointment")
      end

      it "returns 422 with unavailability error" do
        post "/api/v1/therapy_coordinator/operational_management/reassign",
             params: {
               assignment_id: assignment1.id,
               new_teacher_id: teacher2.id
             },
             headers: coordinator_headers

        expect(response).to have_http_status(:unprocessable_content)
        body = response.parsed_body
        expect(body["error"]).to include("marked as unavailable")
        expect(assignment1.reload.teacher_id).to eq(teacher1.id)
      end
    end

    context "when target teacher exceeds capacity" do
      before do
        # Fill capacity of teacher2 (4 students)
        4.times do
          s = create(:student)
          create(:teacher_student_assignment,
                 teacher: teacher2,
                 student: s,
                 session_block_definition: morning_block,
                 therapy_station: station,
                 therapy_room: room,
                 scheduled_date: date,
                 status: "scheduled")
        end
      end

      it "returns 422 with capacity exceeded error" do
        post "/api/v1/therapy_coordinator/operational_management/reassign",
             params: {
               assignment_id: assignment1.id,
               new_teacher_id: teacher2.id
             },
             headers: coordinator_headers

        expect(response).to have_http_status(:unprocessable_content)
        body = response.parsed_body
        expect(body["error"]).to include("exceeds capacity")
      end
    end

    context "when non-coordinator attempts reassignment" do
      it "returns 403 forbidden" do
        post "/api/v1/therapy_coordinator/operational_management/reassign",
             params: { assignment_id: assignment1.id, new_teacher_id: teacher2.id },
             headers: non_coordinator_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/therapy_coordinator/operational_management/performance_metrics (FR-124)" do
    context "when authorized as therapy coordinator" do
      it "returns 200 with teacher performance metrics" do
        get "/api/v1/therapy_coordinator/operational_management/performance_metrics",
            headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to be_an(Array)
        first_teacher = body.find { |m| m["teacher_id"] == teacher1.id }
        expect(first_teacher).to be_present
        expect(first_teacher).to include(
          "sessions_completed",
          "average_trials_per_session",
          "average_independence_percentage",
          "incident_rate",
          "review_status"
        )
      end

      it "returns single teacher metrics when filtered by teacher_id" do
        get "/api/v1/therapy_coordinator/operational_management/performance_metrics",
            params: { teacher_id: teacher1.id },
            headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["teacher_id"]).to eq(teacher1.id)
        expect(body["teacher_name"]).to eq("Teacher Alice")
      end
    end

    context "when unauthorized" do
      it "returns 403 forbidden" do
        get "/api/v1/therapy_coordinator/operational_management/performance_metrics",
            headers: non_coordinator_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /api/v1/therapy_coordinator/operational_management/unassigned_alerts (FR-125)" do
    context "when authorized as therapy coordinator" do
      it "returns 200 with unassigned student alerts" do
        get "/api/v1/therapy_coordinator/operational_management/unassigned_alerts",
            params: { date: date.to_s, session_block_definition_id: morning_block.id },
            headers: coordinator_headers

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["alerts"]).to be_an(Array)
        # student2 is active_therapy and has no assignment in morning_block
        unassigned_student_ids = body["alerts"].map { |a| a["student_id"] }
        expect(unassigned_student_ids).to include(student2.id)
        # student1 is assigned to morning_block, so not in alerts for morning_block
        expect(unassigned_student_ids).not_to include(student1.id)
      end
    end

    context "when unauthorized" do
      it "returns 403 forbidden" do
        get "/api/v1/therapy_coordinator/operational_management/unassigned_alerts",
            headers: non_coordinator_headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
