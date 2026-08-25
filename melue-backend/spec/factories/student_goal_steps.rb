# frozen_string_literal: true

FactoryBot.define do
  factory :student_goal_step do
    association :student_goal
    task_analysis_step_template { nil }
    sequence(:step_number) { |n| n }
    sequence(:name)        { |n| "Step #{n}" }
    independence_percent   { 0.0 }
    status                 { "not_started" }
  end
end
