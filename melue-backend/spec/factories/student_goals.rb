# spec/factories/student_goals.rb
# frozen_string_literal: true

FactoryBot.define do
  factory :student_goal do
    association :goal
    association :therapy_station
    status           { "active" }
    progress_percent { 0.0 }

    # student and iup must be consistent — iup must belong to the same student
    student { association(:student) }
    iup     { association(:iup, student: student) }

    # ===== TRAITS =====
    trait :in_progress do
      status { "in_progress" }
      progress_percent { 30.0 }
    end

    trait :mastered do
      status { "mastered" }
      progress_percent { 100.0 }
    end

    trait :archived do
      status { "archived" }
      progress_percent { 50.0 }
    end

    trait :with_trials do
      after(:create) do |student_goal|
        create_list(:trial, 5, student_goal: student_goal)
      end
    end

    trait :with_clinical_note do
      clinical_note { Faker::Lorem.sentence }
    end
  end
end
