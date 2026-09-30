# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapyCoordinator::TeacherPerformanceMetricsService do
  let(:coordinator_user) { create(:user, :clinical_staff) }
  let(:teacher) { create(:staff_member, role: "teacher", full_name: "Teacher Jane") }
  let(:station) { create(:therapy_station) }
  let(:room) { create(:therapy_room, therapy_station: station) }
  let(:block) { create(:session_block_definition) }
  let(:student1) { create(:student) }
  let(:student2) { create(:student) }
  let(:plus_prompt) { create(:prompt_level, label: "+") }
  let(:gestural_prompt) { create(:prompt_level, label: "G") }
  let(:goal) { create(:student_goal, student: student1, therapy_station: station) }

  describe "#call" do
    context "when teacher has completed sessions with trials and incidents" do
      let!(:session1) do
        sess = create(:therapy_session,
                      teacher: teacher,
                      session_block_definition: block,
                      therapy_station: station,
                      therapy_room: room,
                      status: "in_progress",
                      started_at: 1.day.ago)
        create(:session_participant, therapy_session: sess, student: student1, card_position: :active)
        create(:session_participant, therapy_session: sess, student: student2, card_position: :secondary)
        sess.update!(status: "completed", ended_at: 1.day.ago + 1.hour)
        sess
      end

      let!(:session2) do
        sess = create(:therapy_session,
                      teacher: teacher,
                      session_block_definition: block,
                      therapy_station: station,
                      therapy_room: room,
                      status: "in_progress",
                      started_at: 2.days.ago)
        create(:session_participant, therapy_session: sess, student: student1, card_position: :active)
        create(:session_participant, therapy_session: sess, student: student2, card_position: :secondary)
        sess.update!(status: "completed", ended_at: 2.days.ago + 1.hour)
        sess
      end

      before do
        p1 = session1.active_participant
        p2 = session2.active_participant

        # 4 trials in session 1: 2 independent correct, 1 gestural correct, 1 incorrect
        create(:trial, therapy_session: session1, session_participant: p1, student_goal: goal, prompt_level: plus_prompt, prompt_label_snapshot: "+", outcome: "correct")
        create(:trial, therapy_session: session1, session_participant: p1, student_goal: goal, prompt_level: plus_prompt, prompt_label_snapshot: "+", outcome: "correct")
        create(:trial, therapy_session: session1, session_participant: p1, student_goal: goal, prompt_level: gestural_prompt, prompt_label_snapshot: "G", outcome: "correct")
        create(:trial, therapy_session: session1, session_participant: p1, student_goal: goal, prompt_level: gestural_prompt, prompt_label_snapshot: "G", outcome: "incorrect")

        # 2 trials in session 2: both independent correct
        create(:trial, therapy_session: session2, session_participant: p2, student_goal: goal, prompt_level: plus_prompt, prompt_label_snapshot: "+", outcome: "correct")
        create(:trial, therapy_session: session2, session_participant: p2, student_goal: goal, prompt_level: plus_prompt, prompt_label_snapshot: "+", outcome: "correct")

        # 1 behavior incident for session 1
        create(:behavior_incident, therapy_session: session1, student: student1, staff_member: teacher, occurred_at: 1.day.ago)

        # Session summaries: 1 reviewed, 1 submitted
        create(:session_summary, :reviewed, therapy_session: session1, submitted_at: 1.day.ago, reviewed_by_user: coordinator_user, reviewed_at: 1.day.ago + 30.minutes)
        create(:session_summary, :submitted, therapy_session: session2, submitted_at: 2.days.ago)
      end

      it "calculates all FR-124 metrics accurately for the teacher" do
        service = described_class.new({ teacher_id: teacher.id }, coordinator_user)
        result = service.call

        expect(result).to be_success
        data = result.data

        # 1. Sessions Completed
        expect(data[:sessions_completed]).to eq(2)

        # 2. Trials Logged (Average per Session)
        expect(data[:total_trials]).to eq(6)
        expect(data[:average_trials_per_session]).to eq(3.0)

        # 3. Student Independence Percentage (Average)
        # 4 independent trials out of 6 total trials = 66.67%
        expect(data[:average_independence_percentage]).to eq(66.67)

        # 4. Incident Rate
        # 1 incident / 2 sessions = 0.5
        expect(data[:total_incidents]).to eq(1)
        expect(data[:incident_rate]).to eq(0.5)

        # 5. Review Status
        expect(data[:review_status][:overall_status]).to eq("pending_review")
        expect(data[:review_status][:reviewed_count]).to eq(1)
        expect(data[:review_status][:submitted_count]).to eq(1)
        expect(data[:review_status][:draft_count]).to eq(0)
      end
    end

    context "when teacher has no completed sessions" do
      it "returns zeroed metrics gracefully without divide-by-zero errors" do
        service = described_class.new({ teacher_id: teacher.id }, coordinator_user)
        result = service.call

        expect(result).to be_success
        data = result.data
        expect(data[:sessions_completed]).to eq(0)
        expect(data[:average_trials_per_session]).to eq(0.0)
        expect(data[:average_independence_percentage]).to eq(0.0)
        expect(data[:incident_rate]).to eq(0.0)
        expect(data[:review_status][:overall_status]).to eq("no_sessions")
      end
    end
  end
end
