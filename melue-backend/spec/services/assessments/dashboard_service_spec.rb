# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assessments::DashboardService, type: :service do
  let(:teacher) { create(:staff_member) }
  let(:other_teacher) { create(:staff_member) }

  let(:block_def) { create(:session_block_definition) }
  let(:station)   { create(:therapy_station) }
  let(:room)      { create(:therapy_room, therapy_station: station) }

  def assign!(student, to: teacher)
    create(:teacher_student_assignment,
           teacher:               to,
           student:               student,
           session_block_definition: block_def,
           therapy_station:          station,
           therapy_room:             room,
           scheduled_date:           Date.current)
  end

  let(:student) { create(:student, status: "in_assessment") }

  def result_for(teacher)
    described_class.call(teacher: teacher)
  end

  describe "student scoping" do
    it "returns only students assigned to the current teacher with status in_assessment" do
      assigned = student
      assign!(assigned)

      other_teachers_student = create(:student, status: "in_assessment")
      assign!(other_teachers_student, to: other_teacher)

      not_in_assessment = create(:student, status: "registered")
      assign!(not_in_assessment)

      unassigned = create(:student, status: "in_assessment")

      result = result_for(teacher)

      expect(result).to be_success
      ids = result.data[:students].map { |card| card[:student_id] }
      expect(ids).to contain_exactly(assigned.id)
      expect(ids).not_to include(other_teachers_student.id, not_in_assessment.id, unassigned.id)
    end

    it "excludes students whose assignment has been discarded" do
      student = create(:student, status: "in_assessment")
      assignment = assign!(student)
      assignment.discard

      expect(result_for(teacher).data[:students]).to be_empty
    end
  end

  describe "summary" do
    it "counts completed / in_progress / not_started correctly" do
      completed = create(:student, status: "in_assessment")
      assign!(completed)
      completed_cycle = create(:assessment_cycle, student: completed)
      create(:skills_assessment, assessment_cycle: completed_cycle, status: "submitted", progress_percent: 100)
      create(:behavior_assessment, assessment_cycle: completed_cycle, status: "submitted")
      create(:preference_assessment, assessment_cycle: completed_cycle, status: "submitted")

      in_progress = create(:student, status: "in_assessment")
      assign!(in_progress)
      in_progress_cycle = create(:assessment_cycle, student: in_progress)
      create(:skills_assessment, assessment_cycle: in_progress_cycle, status: "in_progress", progress_percent: 45)
      create(:behavior_assessment, assessment_cycle: in_progress_cycle, status: "draft")

      not_started = create(:student, status: "in_assessment")
      assign!(not_started)

      summary = result_for(teacher).data[:summary]

      expect(summary).to eq(
        total_students: 3,
        completed:      1,
        in_progress:    1,
        not_started:    1
      )
    end
  end

  describe "student card" do
    it "renders ABLLS progress and behavior status from the cycle" do
      assign!(student)
      cycle = create(:assessment_cycle, student: student)
      create(:skills_assessment, assessment_cycle: cycle, status: "in_progress", progress_percent: 45)
      create(:behavior_assessment, assessment_cycle: cycle, status: "draft")

      card = result_for(teacher).data[:students].first

      expect(card[:ablls]).to eq(status: "in_progress", progress_percent: 45)
      expect(card[:behavior]).to eq(status: "draft")
      expect(card[:preference]).to eq(status: "not_started")
      expect(card[:assessment_cycle_id]).to eq(cycle.id)
    end

    it "reports not_started when there is no cycle yet" do
      assign!(student)

      card = result_for(teacher).data[:students].first

      expect(card[:ablls]).to eq(status: "not_started", progress_percent: 0)
      expect(card[:behavior]).to eq(status: "not_started")
      expect(card[:assessment_cycle_id]).to be_nil
    end
  end

  describe "assessment period" do
    it "derives the six-week window from the latest cycle" do
      assign!(student)
      create(:assessment_cycle, student: student, started_on: Date.new(2026, 7, 28))

      period = result_for(teacher).data[:assessment_period]

      expect(period[:start]).to eq("2026-07-28")
      expect(period[:end]).to eq((Date.new(2026, 7, 28) + 6.weeks).to_s)
    end
  end

  describe "query efficiency" do
    it "keeps a constant number of SELECTs as the student count grows (N+1 free)" do
      seed = lambda do |count|
        count.times do
          s = create(:student, status: "in_assessment")
          assign!(s)
          cycle = create(:assessment_cycle, student: s)
          create(:skills_assessment, assessment_cycle: cycle, status: "in_progress")
          create(:behavior_assessment, assessment_cycle: cycle, status: "draft")
        end
      end

      seed.call(2)
      described_class.call(teacher: teacher) # warm up schema cache / prepared statements
      selects_with_two = select_query_count { result_for(teacher) }

      seed.call(4)
      selects_with_six = select_query_count { result_for(teacher) }

      expect(selects_with_six).to eq(selects_with_two)
    end
  end

  private

  def select_query_count
    count = 0
    callback = lambda do |_name, _started, _finished, _id, payload|
      count += 1 if payload[:sql]&.match?(/\A\s*(SELECT|WITH)/i)
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    count
  end
end
