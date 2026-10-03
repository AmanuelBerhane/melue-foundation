# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Sessions", type: :request do
  let(:user)    { create(:user) }
  let(:teacher) { create(:staff_member, user: user) }
  let(:station) { create(:therapy_station) }
  let(:room)    { create(:therapy_room, therapy_station: station) }
  let(:block)   { create(:session_block_definition) }
  let(:student1) { create(:student) }
  let(:student2) { create(:student) }
  let(:headers)  { authenticated_headers(user) }

  let(:session) do
    TherapySession.create!(
      teacher: teacher,
      session_block_definition: block,
      therapy_station: station,
      therapy_room: room,
      status: :in_progress
    )
  end

  let!(:assignment1) do
    TeacherStudentAssignment.create!(
      teacher: teacher,
      student: student1,
      session_block_definition: block,
      therapy_station: station,
      therapy_room: room,
      scheduled_date: Date.current,
      status: "scheduled"
    )
  end

  let!(:assignment2) do
    TeacherStudentAssignment.create!(
      teacher: teacher,
      student: student2,
      session_block_definition: block,
      therapy_station: station,
      therapy_room: room,
      scheduled_date: Date.current,
      status: "scheduled"
    )
  end

  let!(:participant1) do
    SessionParticipant.create!(
      therapy_session: session,
      student: student1,
      teacher_student_assignment: assignment1,
      card_position: :active
    )
  end

  let!(:participant2) do
    SessionParticipant.create!(
      therapy_session: session,
      student: student2,
      teacher_student_assignment: assignment2,
      card_position: :secondary
    )
  end

  let!(:student_goal1) do
    create(:student_goal, student: student1, therapy_station: station)
  end

  let!(:prompt_level) do
    PromptLevel.create!(
      label: "Gestural",
      color: "#2196F3",
      display_order: 1,
      is_active: true
    )
  end

  describe "POST /api/v1/sessions/:id/swap_students" do
    it "persists swapped card positions in the database" do
      expect(participant1.reload.card_position).to eq("active")
      expect(participant2.reload.card_position).to eq("secondary")

      post "/api/v1/sessions/#{session.id}/swap_students", headers: headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["success"]).to be true

      expect(participant1.reload.card_position).to eq("secondary")
      expect(participant2.reload.card_position).to eq("active")

      # Reloading roster reflects the swapped active student first
      get "/api/v1/sessions/#{session.id}/roster", headers: headers
      expect(response).to have_http_status(:ok)
      students = response.parsed_body["students"]
      expect(students.first["id"]).to eq(student2.id.to_s)
      expect(students.second["id"]).to eq(student1.id.to_s)
    end

    it "supports /swap-students alias" do
      post "/api/v1/sessions/#{session.id}/swap-students", headers: headers

      expect(response).to have_http_status(:ok)
      expect(participant1.reload.card_position).to eq("secondary")
      expect(participant2.reload.card_position).to eq("active")
    end

    it "allows swapping back and forth cleanly" do
      post "/api/v1/sessions/#{session.id}/swap_students", headers: headers
      expect(response).to have_http_status(:ok)
      expect(participant1.reload.card_position).to eq("secondary")

      post "/api/v1/sessions/#{session.id}/swap_students", headers: headers
      expect(response).to have_http_status(:ok)
      expect(participant1.reload.card_position).to eq("active")
      expect(participant2.reload.card_position).to eq("secondary")
    end

    it "returns 422 if session has fewer than two participants" do
      single_session = TherapySession.create!(
        teacher: teacher,
        session_block_definition: block,
        therapy_station: station,
        therapy_room: room,
        status: :in_progress
      )
      SessionParticipant.create!(
        therapy_session: single_session,
        student: student1,
        teacher_student_assignment: assignment1,
        card_position: :active
      )

      post "/api/v1/sessions/#{single_session.id}/swap_students", headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to match(/Need exactly two participants to swap/i)
    end
  end

  describe "POST /api/v1/sessions/:id/incidents" do
    it "persists incoming clinical parameters and links student_goal_id" do
      incident_params = {
        student_id: student1.id,
        student_goal_id: student_goal1.id,
        behavior_name: "Aggression",
        behavior_definition: "Hitting desk",
        frequency: "frequently",
        intensity: "severe",
        category: "safety_concerns",
        antecedent: "Difficult Math Task",
        consequence: "Verbal Redirect",
        location: "Station 1",
        notes: "Student redirected successfully"
      }

      post "/api/v1/sessions/#{session.id}/incidents", params: incident_params, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["success"]).to be true

      incident = BehaviorIncident.last
      expect(incident.student_id).to eq(student1.id)
      expect(incident.student_goal_id).to eq(student_goal1.id)
      expect(incident.behavior_name).to eq("Aggression")
      expect(incident.frequency).to eq("frequently")
      expect(incident.intensity).to eq("severe")
      expect(incident.category).to eq("safety_concerns")
      expect(incident.antecedent).to eq("Difficult Math Task")
      expect(incident.consequence).to eq("Verbal Redirect")
      expect(incident.additional_notes).to eq("Student redirected successfully")
    end

    it "automatically links student's active focus goal when student_goal_id is omitted (FR-098c)" do
      participant1.update!(current_focus_student_goal_id: student_goal1.id)

      post "/api/v1/sessions/#{session.id}/incidents",
           params: {
             student_id: student1.id,
             behavior_name: "Flopping",
             frequency: "rarely",
             intensity: "mild",
             category: "flopping"
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      incident = BehaviorIncident.last
      expect(incident.student_goal_id).to eq(student_goal1.id)
      expect(incident.behavior_name).to eq("Flopping")
    end

    it "returns 422 if student is not a participant in the session" do
      other_student = create(:student)

      post "/api/v1/sessions/#{session.id}/incidents",
           params: {
             student_id: other_student.id,
             behavior_name: "Elopement"
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to match(/not a participant/i)
    end

    it "supports POST /api/v1/sessions/:session_id/students/:student_id/incidents route" do
      post "/api/v1/sessions/#{session.id}/students/#{student1.id}/incidents",
           params: {
             behavior: "Vocal Outburst",
             frequency: "constantly",
             intensity: "moderate",
             category: "making_noises"
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      incident = BehaviorIncident.last
      expect(incident.behavior_name).to eq("Vocal Outburst")
      expect(incident.frequency).to eq("constantly")
      expect(incident.intensity).to eq("moderate")
      expect(incident.category).to eq("making_noises")
    end
  end

  describe "Trial logging & undo" do
    it "logs a trial cleanly" do
      trial_params = {
        promptLevel: "Gestural",
        outcome: "correct"
      }

      post "/api/v1/sessions/#{session.id}/students/#{student1.id}/goals/#{student_goal1.id}/trials",
           params: trial_params,
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["success"]).to be true
      expect(json["trial"]["outcome"]).to eq("correct")
      expect(json["trial"]["promptLevel"]).to eq("Gestural")
      expect(session.trials.count).to eq(1)
    end

    it "executes DELETE trials/last cleanly" do
      trial = Trial.create!(
        therapy_session: session,
        session_participant: participant1,
        student_goal: student_goal1,
        prompt_level: prompt_level,
        prompt_label_snapshot: prompt_level.label,
        outcome: :correct,
        client_event_id: SecureRandom.uuid,
        logged_at: Time.current
      )

      expect(session.trials.count).to eq(1)

      delete "/api/v1/sessions/#{session.id}/trials/last", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["success"]).to be true
      expect(Trial.find_by(id: trial.id)).to be_nil
      expect(session.trials.count).to eq(0)
    end

    it "returns success: false when there is no trial to undo" do
      delete "/api/v1/sessions/#{session.id}/trials/last", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["success"]).to be false
      expect(response.parsed_body["message"]).to eq("No trial to undo")
    end

    it "scopes undo by student_id, deleting only that student's last trial" do
      student_goal2 = create(:student_goal, student: student2, therapy_station: station)
      trial1 = Trial.create!(
        therapy_session: session,
        session_participant: participant1,
        student_goal: student_goal1,
        prompt_level: prompt_level,
        prompt_label_snapshot: prompt_level.label,
        outcome: :correct,
        client_event_id: SecureRandom.uuid,
        logged_at: 10.seconds.ago
      )
      trial2 = Trial.create!(
        therapy_session: session,
        session_participant: participant2,
        student_goal: student_goal2,
        prompt_level: prompt_level,
        prompt_label_snapshot: prompt_level.label,
        outcome: :incorrect,
        client_event_id: SecureRandom.uuid,
        logged_at: 5.seconds.ago
      )

      delete "/api/v1/sessions/#{session.id}/students/#{student1.id}/goals/#{student_goal1.id}/trials/last", headers: headers

      expect(response).to have_http_status(:ok)
      expect(Trial.find_by(id: trial1.id)).to be_nil
      expect(Trial.find_by(id: trial2.id)).to be_present
    end

    it "executes nested DELETE students/:student_id/goals/:goal_id/trials/last cleanly" do
      trial = Trial.create!(
        therapy_session: session,
        session_participant: participant1,
        student_goal: student_goal1,
        prompt_level: prompt_level,
        prompt_label_snapshot: prompt_level.label,
        outcome: :correct,
        client_event_id: SecureRandom.uuid,
        logged_at: Time.current
      )

      delete "/api/v1/sessions/#{session.id}/students/#{student1.id}/goals/#{student_goal1.id}/trials/last", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["success"]).to be true
      expect(Trial.find_by(id: trial.id)).to be_nil
    end
  end

  describe "Session completion" do
    it "completes a session with two participants successfully and sets ended_at" do
      post "/api/v1/sessions/#{session.id}/summary",
           params: { notes: "Great dual session" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      session.reload
      expect(session.status).to eq("completed")
      expect(session.ended_at).to be_present
    end

    it "completes a session with a single participant without being blocked" do
      single_session = TherapySession.create!(
        teacher: teacher,
        session_block_definition: block,
        therapy_station: station,
        therapy_room: room,
        status: :in_progress
      )
      SessionParticipant.create!(
        therapy_session: single_session,
        student: student1,
        teacher_student_assignment: assignment1,
        card_position: :active
      )

      post "/api/v1/sessions/#{single_session.id}/summary",
           params: { notes: "Great 1-on-1 session" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(single_session.reload.status).to eq("completed")
    end

    it "blocks completion when session has zero participants" do
      empty_session = TherapySession.create!(
        teacher: teacher,
        session_block_definition: block,
        therapy_station: station,
        therapy_room: room,
        status: :in_progress
      )

      post "/api/v1/sessions/#{empty_session.id}/summary",
           params: { notes: "Empty session" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to match(/must have one or two participants/i)
      expect(empty_session.reload.status).to eq("in_progress")
    end
  end
end
