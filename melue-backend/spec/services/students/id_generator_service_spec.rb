# frozen_string_literal: true

require "rails_helper"

RSpec.describe Students::IdGeneratorService do
  describe ".generate" do
    it "generates student IDs in the format MEL-0001-YY" do
      date = Date.new(2025, 4, 15)
      generated_id = described_class.generate(enrolled_at: date)
      expect(generated_id).to match(/\AMEL-\d{4,}-25\z/)
    end

    it "increments the sequence monotonically for the same year" do
      date = Date.new(2025, 9, 1)
      first_id = described_class.generate(enrolled_at: date)
      Student.create!(
        first_name: "Abebe",
        last_name: "Bikila",
        date_of_birth: 7.years.ago.to_date,
        program_type: :regular,
        therapy_group: :basic,
        guardian_name: "Parent",
        guardian_phone: "0911000000",
        enrolled_at: date,
        student_id: first_id
      )

      second_id = described_class.generate(enrolled_at: date)
      expect(second_id.split("-")[1].to_i).to eq(first_id.split("-")[1].to_i + 1)
    end
  end
end
