# frozen_string_literal: true

FactoryBot.define do
  factory :session_participant do
    association :therapy_session
    association :student
    association :teacher_student_assignment
    card_position { :active }

    trait :secondary do
      card_position { :secondary }
    end
  end
end
