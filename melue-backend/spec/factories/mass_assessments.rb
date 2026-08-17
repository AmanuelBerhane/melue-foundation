# spec/factories/mass_assessments.rb
FactoryBot.define do
  factory :mass_assessment do
    student
    status { 'draft' }
    responses { {} }
    scores { {} }

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
      scores { { sensory: 15, escape: 10, attention: 12, tangible: 8 } }
    end
  end
end
