# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trials::LogTrial, type: :service do
  let(:session)     { create(:therapy_session) }
  let(:assignment) do
    create(:teacher_student_assignment,
           teacher: session.teacher,
           session_block_definition: session.session_block_definition,
           therapy_station: session.therapy_station,
           therapy_room: session.therapy_room)
  end
  let(:participant) do
    create(:session_participant,
           therapy_session: session,
           teacher_student_assignment: assignment)
  end
  let(:goal)     { create(:student_goal, student: participant.student) }
  let(:prompt)   { create(:prompt_level, label: "FP", is_active: true) }
  let(:event_id) { SecureRandom.uuid }

  def call(overrides = {})
    described_class.call(**{
      therapy_session: session,
      participation_id: participant.id,
      student_goal_id: goal.id,
      prompt_level_id: prompt.id,
      outcome: "correct",
      client_event_id: event_id,
      logged_at: Time.current
    }.merge(overrides))
  end

  describe "standard goals" do
    it "logs a trial with no step and recalculates progress" do
      result = call

      expect(result).to be_success
      expect(Trial.last.student_goal_step).to be_nil
      expect(goal.reload.progress_percent).to eq(0.0)
    end

    it "fails when a step is provided for a standard goal" do
      step = create(:student_goal_step, student_goal: goal)

      result = call(student_goal_step_id: step.id)

      expect(result).not_to be_success
      expect(result.error).to match(/standard goals/i)
    end
  end

  describe "task_analysis goals" do
    let(:goal) { create(:student_goal, :task_analysis, student: participant.student) }
    let!(:step) { create(:student_goal_step, student_goal: goal, step_number: 1) }

    it "logs a trial against the step and recalculates progress" do
      result = call(student_goal_step_id: step.id)

      expect(result).to be_success
      expect(Trial.last.student_goal_step_id).to eq(step.id)
      expect(goal.reload.status).to eq("in_progress")
    end

    it "fails when the step is missing" do
      result = call

      expect(result).not_to be_success
      expect(result.error).to match(/step is required/i)
    end

    it "fails when the step belongs to a different student goal" do
      other_goal = create(:student_goal, :task_analysis, student: create(:student))
      other_step = create(:student_goal_step, student_goal: other_goal)

      result = call(student_goal_step_id: other_step.id)

      expect(result).not_to be_success
      expect(result.error).to match(/does not belong/i)
    end
  end

  describe "idempotency" do
    it "returns the existing trial on a duplicate client_event_id" do
      first  = call
      second = call

      expect(second).to be_success
      expect(second.data.id).to eq(first.data.id)
      expect(Trial.count).to eq(1)
    end
  end

  describe "validations" do
    it "fails when the session is not in_progress" do
      session.update_column(:status, "completed")

      expect(call).not_to be_success
      expect(call.error).to match(/not in progress/i)
    end

    it "fails when the participant does not belong to the session" do
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
  end
end
