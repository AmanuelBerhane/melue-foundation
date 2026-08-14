# frozen_string_literal: true

require "rails_helper"

RSpec.describe StudentGoalStep, type: :model do
  it { is_expected.to belong_to(:student_goal) }
  it { is_expected.to belong_to(:task_analysis_step_template).optional }
  it { is_expected.to have_many(:trials).dependent(:nullify) }

  it { is_expected.to validate_presence_of(:step_number) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_numericality_of(:independence_percent)
                        .is_greater_than_or_equal_to(0)
                        .is_less_than_or_equal_to(100) }

  it { is_expected.to define_enum_for(:status)
                        .with_values(not_started: "not_started", in_progress: "in_progress", mastered: "mastered")
                        .backed_by_column_of_type(:string) }
end
