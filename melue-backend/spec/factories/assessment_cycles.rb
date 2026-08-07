# frozen_string_literal: true

FactoryBot.define do
  factory :assessment_cycle do
    association :student
    status     { "in_progress" }
    started_on { Date.current }
  end
end
