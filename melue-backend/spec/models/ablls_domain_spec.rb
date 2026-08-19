# frozen_string_literal: true

require "rails_helper"

RSpec.describe AbllsDomain, type: :model do
  subject { build(:ablls_domain) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_uniqueness_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:position) }
  end

  describe "associations" do
    it { is_expected.to have_many(:ablls_skill_items) }
  end

  describe "scopes" do
    let!(:active_domain)   { create(:ablls_domain, code: "AA", is_active: true, position: 2) }
    let!(:inactive_domain) { create(:ablls_domain, code: "BB", is_active: false, position: 1) }

    it ".active returns only active domains" do
      expect(AbllsDomain.active).to include(active_domain)
      expect(AbllsDomain.active).not_to include(inactive_domain)
    end

    it ".ordered returns domains sorted by position" do
      expect(AbllsDomain.ordered.pluck(:code)).to eq(%w[BB AA])
    end
  end
end
