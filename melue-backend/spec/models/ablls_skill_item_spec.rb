# frozen_string_literal: true

require "rails_helper"

RSpec.describe AbllsSkillItem, type: :model do
  subject { build(:ablls_skill_item) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_uniqueness_of(:identifier) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:position) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:ablls_domain) }
  end

  describe "scopes" do
    let(:domain) { create(:ablls_domain, code: "TST") }
    let!(:item1) { create(:ablls_skill_item, ablls_domain: domain, identifier: "TST1", position: 2) }
    let!(:item2) { create(:ablls_skill_item, ablls_domain: domain, identifier: "TST2", position: 1) }
    let!(:inactive) { create(:ablls_skill_item, :inactive, ablls_domain: domain, identifier: "TST3", position: 3) }

    it ".active returns only active items" do
      expect(AbllsSkillItem.active).to include(item1, item2)
      expect(AbllsSkillItem.active).not_to include(inactive)
    end

    it ".ordered returns items sorted by position" do
      expect(AbllsSkillItem.ordered.where(ablls_domain: domain).pluck(:identifier)).to eq(%w[TST2 TST1 TST3])
    end
  end
end
