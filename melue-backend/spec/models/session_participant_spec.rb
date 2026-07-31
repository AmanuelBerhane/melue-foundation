# frozen_string_literal: true

require "rails_helper"

RSpec.describe SessionParticipant, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:therapy_session) }
    it { is_expected.to belong_to(:student) }
    it { is_expected.to belong_to(:teacher_student_assignment) }
    it { is_expected.to belong_to(:current_focus_student_goal).class_name("StudentGoal").optional }
    it { is_expected.to have_many(:trials).dependent(:restrict_with_error) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:card_position).with_values(active: 0, secondary: 1).backed_by_column_of_type(:integer).with_prefix(:card_position) }
  end

  describe "uniqueness constraints" do
    let(:session) { create(:therapy_session) }
    let(:block)   { session.session_block_definition }
    let(:station) { session.therapy_station }
    let(:room)    { session.therapy_room }

    it "prevents two participants in the same card slot within a session" do
      assignment1 = create(:teacher_student_assignment,
                            teacher: session.teacher,
                            session_block_definition: block,
                            therapy_station: station,
                            therapy_room: room)
      assignment2 = create(:teacher_student_assignment,
                            teacher: session.teacher,
                            session_block_definition: block,
                            therapy_station: station,
                            therapy_room: room)

      create(:session_participant,
             therapy_session: session,
             teacher_student_assignment: assignment1,
             card_position: :active)

      duplicate = build(:session_participant,
                        therapy_session: session,
                        teacher_student_assignment: assignment2,
                        card_position: :active)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:therapy_session_id]).to be_present
    end

    it "prevents the same student appearing twice in a session" do
      student     = create(:student)
      assignment1 = create(:teacher_student_assignment,
                            teacher: session.teacher,
                            student: student,
                            session_block_definition: block,
                            therapy_station: station,
                            therapy_room: room)
      assignment2 = create(:teacher_student_assignment,
                            teacher: session.teacher,
                            student: student,
                            session_block_definition: block,
                            therapy_station: station,
                            therapy_room: room,
                            scheduled_date: Date.current + 1.day)

      create(:session_participant,
             therapy_session: session,
             student: student,
             teacher_student_assignment: assignment1,
             card_position: :active)

      duplicate = build(:session_participant,
                        therapy_session: session,
                        student: student,
                        teacher_student_assignment: assignment2,
                        card_position: :secondary)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:student_id]).to be_present
    end
  end

  describe "#recent_trials" do
    it "returns trials in descending logged_at order up to the limit" do
      session     = create(:therapy_session)
      assignment  = create(:teacher_student_assignment,
                            teacher: session.teacher,
                            session_block_definition: session.session_block_definition,
                            therapy_station: session.therapy_station,
                            therapy_room: session.therapy_room)
      participant = create(:session_participant,
                            therapy_session: session,
                            teacher_student_assignment: assignment)
      goal        = create(:student_goal, student: participant.student, iup: create(:iup, student: participant.student))
      prompt      = create(:prompt_level)

      3.times do |i|
        create(:trial,
               therapy_session: session,
               session_participant: participant,
               student_goal: goal,
               prompt_level: prompt,
               logged_at: i.hours.ago)
      end

      expect(participant.recent_trials(limit: 2).count).to eq(2)
    end
  end
end
