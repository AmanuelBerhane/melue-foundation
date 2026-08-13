# frozen_string_literal: true

require "rails_helper"

RSpec.describe Students::RegisterService, type: :service do
  let(:admin) { create(:staff_member, :admin) }

  def call(staff: admin, params: {})
    described_class.call(params: params, current_user: staff.user)
  end

  let(:valid_basic_params) do
    {
      first_name: "Dawit",
      last_name: "Alemu",
      date_of_birth: 7.years.ago.to_date,
      guardian_name: "Tigist Alemu",
      guardian_phone: "+251911000000",
      program_type: "regular",
      therapy_group: "basic"
    }
  end

  let(:valid_fls_params) do
    {
      first_name: "Sara",
      last_name: "Wolde",
      date_of_birth: 15.years.ago.to_date,
      guardian_name: "Tigist Wolde",
      guardian_phone: "+251911000001",
      program_type: "regular",
      therapy_group: "functional_living"
    }
  end

  describe "success" do
    it "returns a successful result for a valid basic therapy student" do
      expect(call(params: valid_basic_params)).to be_success
    end

    it "creates a student record" do
      expect { call(params: valid_basic_params) }.to change(Student, :count).by(1)
    end

    it "sets status to registered" do
      result = call(params: valid_basic_params)
      expect(result.data.status).to eq("registered")
    end

    it "returns a successful result for a valid FLS student" do
      expect(call(params: valid_fls_params)).to be_success
    end

    it "persists guardian info when provided" do
      params = valid_basic_params.merge(guardian_name: "Tigist Alemu", guardian_phone: "+251911000000")
      result = call(params: params)
      expect(result.data.guardian_name).to eq("Tigist Alemu")
      expect(result.data.guardian_phone).to eq("+251911000000")
    end
  end

  describe "age validation — Basic Therapy (3–12)" do
    it "fails when student is too young (age 2) for basic therapy" do
      params = valid_basic_params.merge(date_of_birth: 2.years.ago.to_date)
      result = call(params: params)
      expect(result).not_to be_success
      expect(result.error).to match(/not appropriate.*basic therapy/i)
    end

    it "fails when student is too old (age 13) for basic therapy" do
      params = valid_basic_params.merge(date_of_birth: 13.years.ago.to_date)
      result = call(params: params)
      expect(result).not_to be_success
      expect(result.error).to match(/not appropriate.*basic therapy/i)
    end

    it "succeeds at the lower bound (age 3)" do
      params = valid_basic_params.merge(date_of_birth: 3.years.ago.to_date)
      expect(call(params: params)).to be_success
    end

    it "succeeds at the upper bound (age 12)" do
      params = valid_basic_params.merge(date_of_birth: 12.years.ago.to_date)
      expect(call(params: params)).to be_success
    end
  end

  describe "age validation — Functional Living Skills (13–19)" do
    it "fails when student is too young (age 12) for FLS" do
      params = valid_fls_params.merge(date_of_birth: 12.years.ago.to_date)
      result = call(params: params)
      expect(result).not_to be_success
      expect(result.error).to match(/not appropriate.*functional living skills/i)
    end

    it "fails when student is too old (age 20) for FLS" do
      params = valid_fls_params.merge(date_of_birth: 20.years.ago.to_date)
      result = call(params: params)
      expect(result).not_to be_success
      expect(result.error).to match(/not appropriate.*functional living skills/i)
    end

    it "succeeds at the lower bound (age 13)" do
      params = valid_fls_params.merge(date_of_birth: 13.years.ago.to_date)
      expect(call(params: params)).to be_success
    end

    it "succeeds at the upper bound (age 19)" do
      params = valid_fls_params.merge(date_of_birth: 19.years.ago.to_date)
      expect(call(params: params)).to be_success
    end
  end

  describe "validation failures" do
    it "fails when first_name is missing" do
      params = valid_basic_params.except(:first_name)
      result = call(params: params)
      expect(result).not_to be_success
      expect(result.error).to match(/first name/i)
    end

    it "fails when date_of_birth is missing" do
      params = valid_basic_params.except(:date_of_birth)
      result = call(params: params)
      expect(result).not_to be_success
    end

    it "does not create a student on failure" do
      params = valid_basic_params.merge(date_of_birth: 2.years.ago.to_date) # too young
      expect { call(params: params) }.not_to change(Student, :count)
    end
  end

  describe "failures" do
    it "fails when current_user has no staff profile" do
      orphan_user = create(:user)
      result = described_class.call(params: valid_basic_params, current_user: orphan_user)
      expect(result).not_to be_success
      expect(result.error).to match(/staff profile required/i)
    end
  end
end
