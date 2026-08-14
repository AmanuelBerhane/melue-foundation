# frozen_string_literal: true

FactoryBot.define do
  factory :task_analysis_step_template do
    association :goal, :task_analysis
    sequence(:step_number) { |n| n }
    sequence(:name)        { |n| "Step #{n}" }
  end
end
