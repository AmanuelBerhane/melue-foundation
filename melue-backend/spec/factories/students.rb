# spec/factories/students.rb
FactoryBot.define do
  factory :student do
    first_name { Faker::Name.first_name }
    middle_name { Faker::Name.middle_name }
    last_name { Faker::Name.last_name }
    date_of_birth { Faker::Date.birthday(min_age: 3, max_age: 12) }
    guardian_name { Faker::Name.name }
    guardian_phone { Faker::PhoneNumber.phone_number }
    guardian_email { Faker::Internet.email }
    diagnosis { Faker::Lorem.sentence }
    program_type { 'regular' }
    therapy_group { 'basic' }
    status { 'draft' }

    trait :draft do
      status { 'draft' }
    end

    trait :regular do
      program_type { 'regular' }
      therapy_group { 'basic' }
    end

    trait :pulled_out do
      program_type { 'pulled_out' }
      therapy_group { 'functional_living' }
    end

    trait :in_assessment do
      status { 'In Assessment' }
      enrolled_at { Time.current }
      assessment_started_at { Time.current }
    end

    trait :enrollment_complete do
      status { 'draft' }

      after(:create) do |student|
        %w[birth_certificate diagnosis_paper agreement].each do |doc_type|
          doc = StudentDocument.create!(
            student: student,
            document_type: doc_type
          )
          doc.file.attach(
            io: StringIO.new('test content'),
            filename: "#{doc_type}.pdf",
            content_type: 'application/pdf'
          )
        end

        student.headshot_photo.attach(
          io: StringIO.new('image data'),
          filename: 'photo.jpg',
          content_type: 'image/jpeg'
        )
        student.save!
      end
    end

    trait :registered do
      status { "registered" }
    end

    trait :basic_therapy_young do
      date_of_birth { Faker::Date.birthday(min_age: 3, max_age: 12) }
      therapy_group { "basic" }
    end

    trait :functional_living do
      date_of_birth { Faker::Date.birthday(min_age: 13, max_age: 19) }
      therapy_group { "functional_living" }
    end

    trait :with_guardian do
      guardian_name  { Faker::Name.name }
      guardian_phone { Faker::PhoneNumber.phone_number }
    end

    trait :with_headshot do
      after(:build) do |student|
        student.headshot_photo.attach(
          io: StringIO.new("fake-image-data"),
          filename: "headshot.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end
