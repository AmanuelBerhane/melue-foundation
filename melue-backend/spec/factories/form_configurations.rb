# frozen_string_literal: true

FactoryBot.define do
  factory :form_configuration do
    sequence(:form_name) { |n| "Form #{n}" }
    form_type   { :enrollment }
    is_default  { false }
    field_schema do
      {
        "fields" => [
          { "id" => "field_1", "type" => "text",   "label" => "Student Name" },
          { "id" => "field_2", "type" => "date",   "label" => "Date" },
          { "id" => "field_3", "type" => "number", "label" => "Age" }
        ]
      }
    end

    trait :enrollment do
      form_type { :enrollment }
      sequence(:form_name) { |n| "Enrollment Form #{n}" }
    end

    trait :iup do
      form_type  { :iup }
      is_default { true }
      sequence(:form_name) { |n| "IUP Form #{n}" }
    end

    trait :ablls do
      form_type { :ablls }
      sequence(:form_name) { |n| "ABLLS Form #{n}" }
    end

    trait :with_complex_schema do
      field_schema do
        {
          "fields" => [
            { "id" => "name",       "type" => "text",        "label" => "Name",          "required" => true },
            { "id" => "dob",        "type" => "date",        "label" => "Date of Birth", "required" => true },
            { "id" => "age",        "type" => "number",      "label" => "Age",           "required" => false },
            { "id" => "notes",      "type" => "textarea",    "label" => "Notes",         "required" => false },
            { "id" => "type",       "type" => "dropdown",    "label" => "Type",          "options" => %w[A B C] },
            { "id" => "active",     "type" => "checkbox",   "label" => "Active" },
            { "id" => "gender",     "type" => "radio",       "label" => "Gender",        "options" => %w[M F] },
            { "id" => "attachment", "type" => "file_upload", "label" => "Attachment" }
          ]
        }
      end
    end
  end
end
