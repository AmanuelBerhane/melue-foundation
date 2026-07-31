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
  end
end
