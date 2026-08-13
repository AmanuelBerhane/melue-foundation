require 'rails_helper'

RSpec.describe "Api::V1::SensoryAssessments", type: :request do
  let!(:student) { Student.first || Student.create!(first_name: "Test", last_name: "Student", date_of_birth: 5.years.ago, program_type: "regular", therapy_group: "basic", guardian_name: "Guardian Name", guardian_phone: "555-0123") }
  let!(:activity) { SensoryActivity.create!(activity_code: "SEN-001", name: "Tactile", is_active: true, display_order: 1) }

  describe "POST /api/v1/sensory_assessments" do
    it "creates a new draft assessment and returns JSON" do
      post "/api/v1/sensory_assessments", params: {
        sensory_assessment: {
          student_id: student.id,
          sensory_assessment_records_attributes: [
            { sensory_activity_id: activity.id, engagement_level: 'Independent', response_reaction: 'Enjoyed' }
          ]
        }
      }
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("draft")
      expect(json["sensory_assessment_records"].size).to eq(1)

      # Submit it
      post "/api/v1/sensory_assessments/#{json["id"]}/submit"
      puts response.body if response.status != 200
      expect(response).to have_http_status(:ok)

      submitted_json = JSON.parse(response.body)
      expect(submitted_json["status"]).to eq("complete")
      expect(submitted_json["summary"]).to be_present
    end
  end
end
