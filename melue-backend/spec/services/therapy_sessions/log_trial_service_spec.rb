# frozen_string_literal: true

require "rails_helper"

RSpec.describe TherapySessions::LogTrialService, type: :service do
  let(:session)     { create(:therapy_session) }
  let(:assignment)  do
    create(:teacher_student_assignment,
           teacher: session.teacher,
           session_block_definition: session.session_block_definition,
           therapy_station: session.therapy_station,
           therapy_room: session.therapy_room)
  end
  let(:participant) { create(:session_participant, therapy_session: session, teacher_student_assignment: assignment) }
  let(:goal)        { create(:student_goal, student: participant.student) }
  let(:prompt)      { create(:prompt_level, label: "FP", is_active: true) }
  let(:event_id)    { SecureRandom.uuid }

  def call(overrides = {})
    described_class.call(**{
      session: session,
      participation_id: participant.id,
      student_goal_id: goal.id,
      prompt_level_id: prompt.id,
      outcome: "correct",
      client_event_id: event_id,
      logged_at: Time.current
    }.merge(overrides))
  end

  describe "success" do
    it "returns a successful result" do
      expect(call).to be_success
    end

    it "creates a trial" do
      expect { call }.to change(Trial, :count).by(1)
    end

    it "snapshots the prompt label at log time" do
      call
      expect(Trial.last.prompt_label_snapshot).to eq("FP")
    end

    it "persists the correct outcome" do
      call
      expect(Trial.last.outcome).to eq("correct")
    end
  end

  describe "idempotency" do
    it "returns the existing trial on duplicate client_event_id" do
      first  = call
      second = call

      expect(second).to be_success
      expect(second.data.id).to eq(first.data.id)
      expect(Trial.count).to eq(1)
    end
  end

  describe "failures" do
    it "fails when the session is not in_progress" do
      session.update_column(:status, "completed")
      expect(call).not_to be_success
      expect(call.error).to match(/not in progress/i)
    end

    it "fails when the participant does not belong to this session" do
      other_participant = create(:session_participant)
      result = call(participation_id: other_participant.id)
      expect(result).not_to be_success
      expect(result.error).to match(/participant not found/i)
    end

    it "fails when the goal does not belong to the participant's student" do
      other_goal = create(:student_goal)
      result = call(student_goal_id: other_goal.id)
      expect(result).not_to be_success
      expect(result.error).to match(/goal does not belong/i)
    end

    it "fails when the prompt level is inactive" do
      prompt.update_column(:is_active, false)
      result = call(prompt_level_id: prompt.id)
      expect(result).not_to be_success
      expect(result.error).to match(/prompt level not found/i)
    end
  end
end
