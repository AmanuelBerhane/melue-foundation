# frozen_string_literal: true

FactoryBot.define do
  factory :iup do
    association :student
    status { "active" }

    trait :draft do
      status { "draft" }
    end

    trait :archived do
      status { "archived" }
    end

    trait :with_assessment_cycle do
      association :assessment_cycle
    end

    trait :with_form_submission do
      after(:create) do |iup|
        form_config = FormConfiguration.find_by(form_type: "iup", is_default: true) ||
                      create(:form_configuration, :iup)
        create(:form_submission, submittable: iup, form_configuration: form_config, status: "draft", values: {})
      end
    end
  end
end
