# spec/factories/fast_assessments.rb
FactoryBot.define do
  factory :fast_assessment do
    student
    status { 'draft' }
    responses { {} }
    risk_indicators { {} }

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
      risk_indicators { { high_risk_count: 2, moderate_risk_count: 3, risk_level: 'moderate' } }
    end
  end
end
