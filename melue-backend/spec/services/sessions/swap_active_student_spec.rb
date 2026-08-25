# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sessions::SwapActiveStudent, type: :service do
  let(:session) { create(:therapy_session) }
  let!(:p1)     { create(:session_participant, therapy_session: session, card_position: :active) }
  let!(:p2)     { create(:session_participant, therapy_session: session, card_position: :secondary) }

  describe "success" do
    it "swaps the active (0) and secondary (1) card positions atomically" do
      result = described_class.call(therapy_session: session)

      expect(result).to be_success
      expect(p1.reload.card_position_secondary?).to be(true)
      expect(p2.reload.card_position_active?).to be(true)
    end

    it "does not mutate teacher_student_assignments" do
      assignments_before = TeacherStudentAssignment.order(:id).pluck(:id, :student_id, :teacher_id)

      described_class.call(therapy_session: session)

      expect(TeacherStudentAssignment.order(:id).pluck(:id, :student_id, :teacher_id))
        .to eq(assignments_before)
    end
  end

  describe "failures" do
    it "fails when the session is not in progress" do
      session.update_column(:status, "completed")

      result = described_class.call(therapy_session: session)

      expect(result).not_to be_success
      expect(result.error).to match(/not in progress/i)
    end

    it "fails unless there are exactly two participants" do
      p2.destroy

      result = described_class.call(therapy_session: session)

      expect(result).not_to be_success
      expect(result.error).to match(/exactly two participants/i)
    end
  end
end
