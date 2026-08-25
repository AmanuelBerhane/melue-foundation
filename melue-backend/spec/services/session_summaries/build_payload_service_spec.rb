# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionSummaries::BuildPayloadService, type: :service do
  let(:session)     { create(:therapy_session) }
  let(:teacher)     { session.teacher }
  let!(:active_participant) { create(:session_participant, card_position: :active, therapy_session: session) }
  let!(:secondary_participant) { create(:session_participant, :secondary, therapy_session: session) }

  let!(:student_goal_active) { create(:student_goal, student: active_participant.student, therapy_station: session.therapy_station) }
  let!(:student_goal_sec) { create(:student_goal, student: secondary_participant.student, therapy_station: session.therapy_station) }

  def call
    described_class.call(session: session)
  end

  describe "success" do
    it "creates a draft summary if missing" do
      expect(session.session_summary).to be_nil
      result = call
      expect(result).to be_success
      expect(session.reload.session_summary).to be_present
      expect(session.session_summary.status).to eq("draft")
    end

    it "creates or reuses an existing summary if present" do
      summary = create(:session_summary, therapy_session: session, status: :draft, qualitative_notes: "existing")
      result = call
      expect(result).to be_success
      expect(result.data[:summary][:id]).to eq(summary.id)
      expect(result.data[:summary][:qualitative_notes]).to eq("existing")
    end

    it "returns session header fields" do
      result = call
      expect(result).to be_success
      expect(result.data[:session][:id]).to eq(session.id)
      expect(result.data[:session][:station][:name]).to eq(session.therapy_station.name)
      expect(result.data[:session][:room][:name]).to eq(session.therapy_room.name)
      expect(result.data[:session][:teacher][:name]).to eq(teacher.full_name)
      expect(result.data[:session][:block][:name]).to eq(session.session_block_definition.name)
      expect(result.data[:session][:total_duration_minutes]).to be_present
    end

    it "orders participants active first" do
      result = call
      participants = result.data[:participants]
      expect(participants.size).to eq(2)
      expect(participants[0][:id]).to eq(active_participant.id)
      expect(participants[1][:id]).to eq(secondary_participant.id)
    end

    it "calculates total trials, prompt breakdown, and independence percentage" do
      prompt1 = create(:prompt_level, label: "+")
      prompt2 = create(:prompt_level, label: "G")

      # Log 3 trials for active participant:
      # Trial 1: correct, prompt label "+" (independent)
      # Trial 2: correct, prompt label "G" (assisted)
      # Trial 3: incorrect, prompt label "+"
      create(:trial, therapy_session: session, session_participant: active_participant, student_goal: student_goal_active, prompt_level: prompt1, prompt_label_snapshot: "+", outcome: "correct")
      create(:trial, therapy_session: session, session_participant: active_participant, student_goal: student_goal_active, prompt_level: prompt2, prompt_label_snapshot: "G", outcome: "correct")
      create(:trial, therapy_session: session, session_participant: active_participant, student_goal: student_goal_active, prompt_level: prompt1, prompt_label_snapshot: "+", outcome: "incorrect")

      result = call
      goal_payload = result.data[:participants][0][:goals].find { |g| g[:id] == student_goal_active.id }

      expect(goal_payload[:total_trials]).to eq(3)
      expect(goal_payload[:prompt_breakdown]).to eq({ "+" => 2, "G" => 1 })
      # Independent correct: 1 (out of 3). 1/3 = 33.33%
      expect(goal_payload[:independence_percentage]).to eq(33.33)
    end

    it "ignores renamed prompt levels by using snapshot values" do
      prompt = create(:prompt_level, label: "OldLabel")
      create(:trial, therapy_session: session, session_participant: active_participant, student_goal: student_goal_active, prompt_level: prompt, prompt_label_snapshot: "OldLabel", outcome: "correct")

      # Rename prompt level
      prompt.update!(label: "NewLabel")

      result = call
      goal_payload = result.data[:participants][0][:goals].find { |g| g[:id] == student_goal_active.id }
      expect(goal_payload[:prompt_breakdown]).to eq({ "OldLabel" => 1 })
    end

    it "calculates zero independence when no trials exist" do
      result = call
      goal_payload = result.data[:participants][0][:goals].find { |g| g[:id] == student_goal_active.id }
      expect(goal_payload[:total_trials]).to eq(0)
      expect(goal_payload[:independence_percentage]).to eq(0.0)
    end

    it "returns empty behavior incident list when none exist" do
      result = call
      expect(result.data[:behavior_incidents]).to eq([])
    end
  end
end
