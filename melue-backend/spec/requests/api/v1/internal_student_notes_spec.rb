# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::InternalStudentNotes", type: :request do
  let(:student) { create(:student) }
  let(:path) { "/api/v1/students/#{student.id}/internal_notes" }

  context "as a Director" do
    let(:headers) { director_headers }

    it "persists a note with internal_flag: true (FR-135)" do
      expect {
        post path, params: { content: "Recommend transition next semester." }, headers: headers, as: :json
      }.to change(InternalStudentNote, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["data"]).to include("content" => "Recommend transition next semester.",
                                                      "internal_flag" => true)
      expect(InternalStudentNote.last.internal_flag).to be(true)
    end

    it "lists the student's notes" do
      create_list(:internal_student_note, 2, student: student)

      get path, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].size).to eq(2)
    end

    it "updates and deletes a note" do
      note = create(:internal_student_note, student: student)

      patch "#{path}/#{note.id}", params: { content: "Updated" }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(note.reload.content).to eq("Updated")

      delete "#{path}/#{note.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(InternalStudentNote.exists?(note.id)).to be(false)
    end

    it "returns 422 for blank content" do
      post path, params: { content: " " }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for an unknown student" do
      get "/api/v1/students/#{SecureRandom.uuid}/internal_notes", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  it "returns a clean 403 for a teacher" do
    get path, headers: teacher_headers

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body["error"]).to match(/Director or Administrator/)
  end

  it "returns a clean 403 for a therapy coordinator" do
    post path, params: { content: "x" }, headers: therapy_coordinator_headers, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects non-internal notes at the model level" do
    note = build(:internal_student_note, internal_flag: false)
    expect(note).not_to be_valid
  end
end
