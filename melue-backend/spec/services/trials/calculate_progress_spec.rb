# frozen_string_literal: true

require "rails_helper"

RSpec.describe Trials::CalculateProgress, type: :service do
  let(:student)   { create(:student) }
  let(:iup)       { create(:iup, student: student) }
  let(:session)   { create(:therapy_session) }
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
           student: student,
           teacher_student_assignment: assignment)
  end

  let(:independent_prompt) { create(:prompt_level, label: "+", is_active: true) }
  let(:prompted_prompt)    { create(:prompt_level, label: "FP", is_active: true) }

  def create_trial(student_goal:, prompt_level:, step: nil, outcome: "correct")
    create(:trial,
           therapy_session: session,
           session_participant: participant,
           student_goal: student_goal,
           student_goal_step: step,
           prompt_level: prompt_level,
           outcome: outcome,
           client_event_id: SecureRandom.uuid)
  end

  describe "standard goals" do
    let(:goal) { create(:student_goal, student: student, iup: iup, progress_percent: 0.0) }

    it "computes independence % from independent (correct + '+') trials" do
      create_trial(student_goal: goal, prompt_level: independent_prompt)
      create_trial(student_goal: goal, prompt_level: prompted_prompt)
      create_trial(student_goal: goal, prompt_level: prompted_prompt, outcome: "incorrect")

      result = described_class.call(student_goal: goal)

      expect(result).to be_success
      expect(result.data[:total_trials]).to eq(3)
      expect(result.data[:independent_trials]).to eq(1)
      expect(result.data[:independence_percent]).to eq(33.33)
      expect(goal.reload.progress_percent).to be_within(0.01).of(33.33)
    end

    it "keeps 0% when there are no trials" do
      result = described_class.call(student_goal: goal)

      expect(result.data[:total_trials]).to eq(0)
      expect(result.data[:independence_percent]).to eq(0.0)
      expect(goal.reload.progress_percent).to eq(0.0)
    end
  end

  describe "task_analysis goals" do
    let(:goal) { create(:student_goal, :task_analysis, student: student, iup: iup) }
    let!(:step1) { create(:student_goal_step, student_goal: goal, step_number: 1, name: "Turn on water") }
    let!(:step2) { create(:student_goal_step, student_goal: goal, step_number: 2, name: "Wet hands") }

    it "computes per-step stats and the overall mastered percentage" do
      create_trial(student_goal: goal, step: step1, prompt_level: independent_prompt)
      create_trial(student_goal: goal, step: step1, prompt_level: prompted_prompt)
      3.times { create_trial(student_goal: goal, step: step2, prompt_level: independent_prompt) }

      result = described_class.call(student_goal: goal)

      expect(result).to be_success

      s1 = result.data[:steps].find { |s| s[:id] == step1.id }
      s2 = result.data[:steps].find { |s| s[:id] == step2.id }
      expect(s1[:total_trials]).to eq(2)
      expect(s1[:independent_trials]).to eq(1)
      expect(s1[:independence_percent]).to eq(50.0)
      expect(s1[:status]).to eq("in_progress")
      expect(s2[:status]).to eq("mastered")

      expect(result.data[:total_steps]).to eq(2)
      expect(result.data[:mastered_steps_count]).to eq(1)
      expect(result.data[:steps_mastered_percent]).to eq(50.0)
      expect(result.data[:goal_mastered]).to be(false)

      expect(step1.reload.independence_percent).to be_within(0.01).of(50.0)
      expect(step2.reload.status).to eq("mastered")
      expect(goal.reload.progress_percent).to be_within(0.01).of(50.0)
    end

    it "flags goal_mastered and marks the goal mastered when all steps are mastered" do
      3.times { create_trial(student_goal: goal, step: step1, prompt_level: independent_prompt) }
      3.times { create_trial(student_goal: goal, step: step2, prompt_level: independent_prompt) }

      result = described_class.call(student_goal: goal)

      expect(result.data[:goal_mastered]).to be(true)
      expect(goal.reload.status).to eq("mastered")
      expect(goal.reload.progress_percent).to be_within(0.01).of(100.0)
    end

    it "treats prompted and incorrect trials as non-independent" do
      2.times { create_trial(student_goal: goal, step: step1, prompt_level: independent_prompt, outcome: "incorrect") }
      1.times { create_trial(student_goal: goal, step: step1, prompt_level: prompted_prompt) }

      described_class.call(student_goal: goal)

      expect(step1.reload.independence_percent).to eq(0.0)
      expect(step1.reload.status).to eq("in_progress")
    end
  end
end
