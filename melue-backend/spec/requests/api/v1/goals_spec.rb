# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Goal Bank API", type: :request do
  let!(:domain_comm) { create(:goal_domain, name: "Communication", display_order: 1) }
  let!(:domain_motor) { create(:goal_domain, name: "Motor Skills", display_order: 2) }
  let!(:domain_self_help) { create(:goal_domain, name: "Self-Help", display_order: 3) }

  let(:director_user) { create(:user) }
  let(:director_staff) { create(:staff_member, :program_director, user: director_user) }
  let(:director_headers) do
    director_staff
    auth_headers(director_user)
  end

  let(:teacher_user) { create(:user, :therapist) }
  let(:teacher_staff) { create(:staff_member, user: teacher_user, role: "teacher") }
  let(:teacher_headers) do
    teacher_staff
    auth_headers(teacher_user)
  end

  # ==============================================================================
  # FR-071, FR-072, FR-073, FR-078: GET /api/v1/goals (Search, Filters, Usage Count)
  # ==============================================================================
  describe "GET /api/v1/goals" do
    let!(:goal1) do
      create(:goal,
        name: "Expressive Labels",
        description: "Student will tact 10 common items",
        goal_domain: domain_comm,
        goal_type: "standard",
        suggested_age_range: "3-5",
        mastery_criteria: { target: "80% accuracy" },
        applicable_therapy_groups: [ "basic" ],
        is_active: true
      )
    end

    let!(:goal2) do
      create(:goal, :task_analysis,
        name: "Hand Washing",
        description: "Wash hands in bathroom sink",
        goal_domain: domain_self_help,
        suggested_age_range: "3-8",
        mastery_criteria: { target: "100% independence across 3 sessions" },
        applicable_therapy_groups: [ "basic", "functional_living" ],
        is_active: true
      )
    end

    let!(:inactive_goal) do
      create(:goal,
        name: "Deprecated Motor Activity",
        description: "Old protocol",
        goal_domain: domain_motor,
        is_active: false
      )
    end

    let(:active_student) { create(:student, status: "active") }
    let(:station) { create(:therapy_station) }

    before do
      iup = create(:iup, student: active_student, status: "active")
      create(:student_goal, goal: goal1, student: active_student, iup: iup, therapy_station: station, status: "active")
    end

    it "lists active goals with metadata, criteria, domain, and usage count (FR-071, FR-078)" do
      get "/api/v1/goals", headers: teacher_headers

      expect(response).to have_http_status(:ok)
      expect(json["goals"].size).to eq(2) # Only active goals by default

      found_goal1 = json["goals"].find { |g| g["id"] == goal1.id }
      expect(found_goal1["name"]).to eq("Expressive Labels")
      expect(found_goal1["goal_domain"]["name"]).to eq("Communication")
      expect(found_goal1["suggested_age_range"]).to eq("3-5")
      expect(found_goal1["mastery_criteria_template"]["target"]).to eq("80% accuracy")
      expect(found_goal1["usage_count"]).to eq(1)

      found_goal2 = json["goals"].find { |g| g["id"] == goal2.id }
      expect(found_goal2["usage_count"]).to eq(0)

      # Includes domain filter chips (FR-073)
      expect(json["domains"]).to be_an(Array)
      comm_chip = json["domains"].find { |d| d["name"] == "Communication" }
      expect(comm_chip).to be_present
      expect(comm_chip["goal_count"]).to eq(1)
    end

    it "searches goals by name (FR-072)" do
      get "/api/v1/goals", params: { q: "Washing" }, headers: teacher_headers

      expect(response).to have_http_status(:ok)
      expect(json["goals"].size).to eq(1)
      expect(json["goals"].first["name"]).to eq("Hand Washing")
    end

    it "searches goals by keyword in description (FR-072)" do
      get "/api/v1/goals", params: { q: "tact 10" }, headers: teacher_headers

      expect(response).to have_http_status(:ok)
      expect(json["goals"].size).to eq(1)
      expect(json["goals"].first["name"]).to eq("Expressive Labels")
    end

    it "filters goals by domain chip (FR-073)" do
      get "/api/v1/goals", params: { goal_domain_id: domain_self_help.id }, headers: teacher_headers

      expect(response).to have_http_status(:ok)
      expect(json["goals"].size).to eq(1)
      expect(json["goals"].first["id"]).to eq(goal2.id)
    end

    it "filters goals by goal_type (FR-078a)" do
      get "/api/v1/goals", params: { goal_type: "task_analysis" }, headers: teacher_headers

      expect(response).to have_http_status(:ok)
      expect(json["goals"].size).to eq(1)
      expect(json["goals"].first["id"]).to eq(goal2.id)
    end

    it "filters inactive goals when requested" do
      get "/api/v1/goals", params: { is_active: "false" }, headers: teacher_headers

      expect(response).to have_http_status(:ok)
      expect(json["goals"].size).to eq(1)
      expect(json["goals"].first["id"]).to eq(inactive_goal.id)
    end

    it "searches via legacy GET /api/v1/goals/search" do
      get "/api/v1/goals/search", params: { q: "Labels" }, headers: teacher_headers

      expect(response).to have_http_status(:ok)
      expect(json["goals"].size).to eq(1)
      expect(json["goals"].first["name"]).to eq("Expressive Labels")
    end
  end

  # ==============================================================================
  # GET /api/v1/goals/:id
  # ==============================================================================
  describe "GET /api/v1/goals/:id" do
    let(:goal) { create(:goal, :task_analysis, goal_domain: domain_self_help, name: "Shoe Tying") }

    before do
      create(:task_analysis_step_template, goal: goal, step_number: 1, name: "Cross laces")
      create(:task_analysis_step_template, goal: goal, step_number: 2, name: "Make loop")
    end

    it "returns single goal with steps and domain" do
      get "/api/v1/goals/#{goal.id}", headers: teacher_headers

      expect(response).to have_http_status(:ok)
      expect(json["name"]).to eq("Shoe Tying")
      expect(json["steps"].size).to eq(2)
      expect(json["steps"][0]["step_number"]).to eq(1)
      expect(json["steps"][0]["name"]).to eq("Cross laces")
      expect(json["steps"][1]["step_number"]).to eq(2)
      expect(json["steps"][1]["name"]).to eq("Make loop")
    end

    it "returns 404 for unknown goal" do
      get "/api/v1/goals/#{SecureRandom.uuid}", headers: teacher_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ==============================================================================
  # FR-074, FR-078a, FR-078b: POST /api/v1/goals (Add new goals)
  # ==============================================================================
  describe "POST /api/v1/goals" do
    it "allows Program Directors to add a Standard Goal (SCR-PD-006, FR-074, FR-078a)" do
      params = {
        goal: {
          name: "Identify Colors",
          description: "Receptive identification of primary colors",
          goal_domain_id: domain_comm.id,
          goal_type: "standard",
          suggested_age_range: "2-4",
          applicable_therapy_groups: [ "basic" ],
          mastery_criteria: { target: "90% over 3 days" }
        }
      }

      post "/api/v1/goals", params: params, headers: director_headers

      expect(response).to have_http_status(:created)
      expect(json["name"]).to eq("Identify Colors")
      expect(json["goal_type"]).to eq("standard")
      expect(json["goal_domain_id"]).to eq(domain_comm.id)
      expect(json["usage_count"]).to eq(0)

      created_goal = Goal.find(json["id"])
      expect(created_goal.is_active).to be true
    end

    it "allows Program Directors to add a Task Analysis Goal with steps (FR-078b)" do
      params = {
        goal: {
          name: "Tooth Brushing",
          description: "Complete dental hygiene sequence",
          goal_domain_id: domain_self_help.id,
          goal_type: "task_analysis",
          suggested_age_range: "4-10",
          mastery_criteria: { target: "100% independence" },
          steps: [
            { step_number: 1, name: "Apply toothpaste", description: "Pea size amount", mastery_criteria: { prompt: "independent" } },
            { step_number: 2, name: "Brush outside teeth", description: "Brush 30s", mastery_criteria: { prompt: "independent" } },
            { step_number: 3, name: "Rinse mouth", description: "Rinse with cup", mastery_criteria: { prompt: "independent" } }
          ]
        }
      }

      post "/api/v1/goals", params: params, headers: director_headers

      expect(response).to have_http_status(:created)
      expect(json["goal_type"]).to eq("task_analysis")
      expect(json["steps"].size).to eq(3)
      expect(json["steps"][0]["name"]).to eq("Apply toothpaste")
      expect(json["steps"][1]["step_number"]).to eq(2)
      expect(json["steps"][2]["description"]).to eq("Rinse with cup")

      created_goal = Goal.find(json["id"])
      expect(created_goal.task_analysis_step_templates.count).to eq(3)
    end

    it "forbids non-Program Directors from creating goals (FR-074)" do
      params = {
        goal: {
          name: "Teacher Created Goal",
          goal_domain_id: domain_comm.id,
          goal_type: "standard"
        }
      }

      post "/api/v1/goals", params: params, headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
      expect(json["error"]).to include("Program Director access required")
    end

    it "returns 422 if required attributes are missing" do
      params = {
        goal: {
          name: "",
          goal_type: "standard"
        }
      }

      post "/api/v1/goals", params: params, headers: director_headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to be_present
    end
  end

  # ==============================================================================
  # FR-075: PUT/PATCH /api/v1/goals/:id (Edit goal details)
  # ==============================================================================
  describe "PATCH /api/v1/goals/:id" do
    let(:goal) { create(:goal, goal_domain: domain_comm, name: "Original Title", description: "Old desc") }

    it "allows Program Directors to edit goal details (FR-075)" do
      patch "/api/v1/goals/#{goal.id}",
            params: { goal: { name: "Updated Title", description: "New desc" } },
            headers: director_headers

      expect(response).to have_http_status(:ok)
      expect(json["name"]).to eq("Updated Title")
      expect(json["description"]).to eq("New desc")
      expect(goal.reload.name).to eq("Updated Title")
    end

    it "allows updating task analysis steps in sequence (FR-075, FR-078b)" do
      ta_goal = create(:goal, :task_analysis, goal_domain: domain_self_help, name: "Steps Goal")
      step1 = create(:task_analysis_step_template, goal: ta_goal, step_number: 1, name: "Old Step 1")

      patch "/api/v1/goals/#{ta_goal.id}",
            params: {
              goal: {
                steps: [
                  { id: step1.id, step_number: 1, name: "Updated Step 1" },
                  { step_number: 2, name: "Newly Added Step 2", description: "Second step" }
                ]
              }
            },
            headers: director_headers

      expect(response).to have_http_status(:ok)
      expect(json["steps"].size).to eq(2)
      expect(json["steps"][0]["name"]).to eq("Updated Step 1")
      expect(json["steps"][1]["name"]).to eq("Newly Added Step 2")
    end

    it "forbids non-Program Directors from editing goals (FR-075)" do
      patch "/api/v1/goals/#{goal.id}",
            params: { goal: { name: "Unauthorized Edit" } },
            headers: teacher_headers

      expect(response).to have_http_status(:forbidden)
      expect(goal.reload.name).to eq("Original Title")
    end
  end

  # ==============================================================================
  # FR-076: PATCH /api/v1/goals/:id/deactivate (Deactivate goal)
  # ==============================================================================
  describe "PATCH /api/v1/goals/:id/deactivate" do
    let(:goal) { create(:goal, goal_domain: domain_comm, is_active: true) }
    let(:student) { create(:student, status: "active") }
    let(:station) { create(:therapy_station) }

    it "deactivates the goal, preventing new assignments while preserving existing (FR-076)" do
      # Existing assignment
      iup = create(:iup, student: student, status: "active")
      existing_student_goal = create(:student_goal, goal: goal, student: student, iup: iup, therapy_station: station, status: "active")

      patch "/api/v1/goals/#{goal.id}/deactivate", headers: director_headers

      expect(response).to have_http_status(:ok)
      expect(json["goal"]["is_active"]).to be false
      expect(goal.reload.is_active).to be false

      # Existing assignment preserved
      expect(existing_student_goal.reload.status).to eq("active")

      # Attempting new assignment with deactivated goal fails
      new_student = create(:student, status: "active")
      post "/api/v1/goal_assignments",
           params: { student_id: new_student.id, goal_id: goal.id, station_id: station.id },
           headers: director_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to include("Goal is not active")
    end

    it "reactivates a goal with activate endpoint" do
      goal.update!(is_active: false)

      patch "/api/v1/goals/#{goal.id}/activate", headers: director_headers

      expect(response).to have_http_status(:ok)
      expect(json["goal"]["is_active"]).to be true
      expect(goal.reload.is_active).to be true
    end

    it "forbids non-Program Directors from deactivating goals" do
      patch "/api/v1/goals/#{goal.id}/deactivate", headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
      expect(goal.reload.is_active).to be true
    end
  end

  # ==============================================================================
  # FR-077: DELETE /api/v1/goals/:id (Deletion protection)
  # ==============================================================================
  describe "DELETE /api/v1/goals/:id" do
    let(:goal) { create(:goal, goal_domain: domain_comm) }
    let(:active_student) { create(:student, status: "active") }
    let(:station) { create(:therapy_station) }

    it "prevents deletion of goals currently assigned to active students (FR-077)" do
      iup = create(:iup, student: active_student, status: "active")
      create(:student_goal, goal: goal, student: active_student, iup: iup, therapy_station: station, status: "active")

      delete "/api/v1/goals/#{goal.id}", headers: director_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to include("Cannot delete goal currently assigned to active students")
      expect(Goal.exists?(goal.id)).to be true
    end

    it "allows deletion of goals not assigned to active students (FR-077)" do
      delete "/api/v1/goals/#{goal.id}", headers: director_headers

      expect(response).to have_http_status(:no_content)
      expect(Goal.exists?(goal.id)).to be false
    end

    it "forbids non-Program Directors from deleting goals" do
      delete "/api/v1/goals/#{goal.id}", headers: teacher_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ==============================================================================
  # FR-078b: POST /api/v1/goals/upload_template (Upload task analysis template)
  # ==============================================================================
  describe "POST /api/v1/goals/upload_template" do
    let(:json_template_payload) do
      {
        task_name: "Morning Arrival Routine",
        description: "Sequence for student arriving at school",
        domain_name: "Communication",
        suggested_age_range: "4-7",
        mastery_criteria: { target_percent: 80, consecutive_days: 3 },
        steps: [
          { step_number: 1, name: "Hang up coat", description: "Hang on designated hook", mastery_criteria: { prompt: "independent" } },
          { step_number: 2, name: "Unpack folder", description: "Place in homework bin", mastery_criteria: { prompt: "independent" } },
          { step_number: 3, name: "Sit at desk", description: "Takes seat calmly", mastery_criteria: { prompt: "independent" } }
        ]
      }.to_json
    end

    it "creates a Task Analysis goal from uploaded JSON template data (FR-078b)" do
      post "/api/v1/goals/upload_template",
           params: { template: json_template_payload },
           headers: director_headers

      expect(response).to have_http_status(:created)
      expect(json["name"]).to eq("Morning Arrival Routine")
      expect(json["goal_type"]).to eq("task_analysis")
      expect(json["steps"].size).to eq(3)
      expect(json["steps"][0]["name"]).to eq("Hang up coat")
      expect(json["steps"][2]["name"]).to eq("Sit at desk")
    end

    it "creates a Task Analysis goal from uploaded CSV file (FR-078b)" do
      csv_content = <<~CSV
        task_name,Making a Snack
        description,Prepare simple snack independently
        domain_name,Self-Help
        suggested_age_range,6-12
        step_number,name,description,mastery_criteria
        1,Get plate,Open cabinet and take 1 paper plate,Independent
        2,Get snack,Retrieve pretzels from pantry,Independent
        3,Pour portion,Pour 1 handful onto plate,Independent
      CSV

      temp_file = Rack::Test::UploadedFile.new(
        StringIO.new(csv_content),
        "text/csv",
        original_filename: "snack_template.csv"
      )

      post "/api/v1/goals/upload_template",
           params: { file: temp_file },
           headers: director_headers

      expect(response).to have_http_status(:created)
      expect(json["name"]).to eq("Making a Snack")
      expect(json["goal_type"]).to eq("task_analysis")
      expect(json["steps"].size).to eq(3)
      expect(json["steps"][0]["name"]).to eq("Get plate")
    end

    it "forbids non-Program Directors from uploading templates (FR-078b)" do
      post "/api/v1/goals/upload_template",
           params: { template: json_template_payload },
           headers: teacher_headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
