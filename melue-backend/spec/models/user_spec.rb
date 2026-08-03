# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_one(:staff_member).dependent(:restrict_with_error) }
  end

  describe "validations" do
    subject { User.create!(email: "test_user@melue.foundation", password_hash: "$2a$12$eImiTXuWVxfM37uY4JANjO5E.86J.qj3Rk4mGZ3y.uK98g3Y2m") }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end
end
