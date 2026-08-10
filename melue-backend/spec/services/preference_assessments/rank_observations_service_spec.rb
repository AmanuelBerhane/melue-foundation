# frozen_string_literal: true

require "rails_helper"

RSpec.describe PreferenceAssessments::RankObservationsService, type: :service do
  let(:assessment) { create(:preference_assessment) }

  def observe(name:, duration:, frequency:, context: "sensory_time", category: "Toys")
    create(:preference_observation,
           preference_assessment:     assessment,
           preference_inventory_item: create(:preference_inventory_item,
                                             name: name, category: category),
           context:                   context,
           duration_seconds:          duration,
           frequency_count:           frequency)
  end

  describe "combined score (FR-047c)" do
    it "weights normalised duration at 60% and normalised frequency at 40%" do
      # max duration 300, max frequency 20
      top    = observe(name: "Swing",      duration: 300, frequency: 10)
      second = observe(name: "Sand play",  duration: 150, frequency: 20)

      described_class.call(preference_assessment: assessment)

      # 0.6 * (300/300) + 0.4 * (10/20) = 0.80
      expect(top.reload.combined_score.to_f).to eq(80.0)
      # 0.6 * (150/300) + 0.4 * (20/20) = 0.70
      expect(second.reload.combined_score.to_f).to eq(70.0)
    end

    it "lets a high frequency outrank a longer single engagement" do
      long_but_rare = observe(name: "Slide",     duration: 100, frequency: 1)
      short_but_often = observe(name: "Balloon", duration: 60,  frequency: 100)

      described_class.call(preference_assessment: assessment)

      # 0.6*0.60 + 0.4*1.00 = 0.76  beats  0.6*1.00 + 0.4*0.01 = 0.604
      expect(short_but_often.reload.rank).to eq(1)
      expect(long_but_rare.reload.rank).to eq(2)
    end

    it "scores everything zero when nothing was engaged with" do
      first  = observe(name: "Piano", duration: 0, frequency: 0)
      second = observe(name: "Watch", duration: 0, frequency: 0)

      described_class.call(preference_assessment: assessment)

      expect([ first.reload, second.reload ].map { |o| o.combined_score.to_f }).to eq([ 0.0, 0.0 ])
      expect([ first, second ].map(&:tier)).to all(eq("low"))
    end
  end

  describe "ranking (FR-048)" do
    it "numbers ranks from 1 with no gaps" do
      observe(name: "A item", duration: 300, frequency: 9)
      observe(name: "B item", duration: 200, frequency: 6)
      observe(name: "C item", duration: 100, frequency: 3)

      described_class.call(preference_assessment: assessment)

      expect(assessment.preference_observations.order(:rank).pluck(:rank)).to eq([ 1, 2, 3 ])
    end

    it "breaks ties on item name so repeat runs are stable" do
      zulu  = observe(name: "Zulu drum", duration: 120, frequency: 4)
      alpha = observe(name: "Alpha ball", duration: 120, frequency: 4)

      described_class.call(preference_assessment: assessment)
      expect(alpha.reload.rank).to eq(1)
      expect(zulu.reload.rank).to eq(2)

      described_class.call(preference_assessment: assessment)
      expect(alpha.reload.rank).to eq(1)
      expect(zulu.reload.rank).to eq(2)
    end

    it "ranks each context independently" do
      sensory = observe(name: "Lotion", duration: 90, frequency: 3, context: "sensory_time")
      circle  = observe(name: "Music",  duration: 10, frequency: 1, context: "circle_time")
      play    = observe(name: "Slide",  duration: 40, frequency: 2, context: "play_time")

      described_class.call(preference_assessment: assessment)

      expect([ sensory.reload.rank, circle.reload.rank, play.reload.rank ]).to eq([ 1, 1, 1 ])
    end

    it "only re-ranks the requested context" do
      sensory = observe(name: "Lotion", duration: 90, frequency: 3, context: "sensory_time")
      circle  = observe(name: "Music",  duration: 10, frequency: 1, context: "circle_time")

      described_class.call(preference_assessment: assessment, context: "circle_time")

      expect(circle.reload.rank).to eq(1)
      expect(sensory.reload.rank).to be_nil
    end
  end

  describe "tiers" do
    it "splits engaged items into highest, moderate and low thirds" do
      items = 6.downto(1).map do |n|
        observe(name: "Item #{n}", duration: n * 100, frequency: n)
      end

      described_class.call(preference_assessment: assessment)

      by_rank = assessment.preference_observations.order(:rank).to_a
      expect(by_rank.map(&:tier))
        .to eq(%w[highest highest moderate moderate low low])
      expect(items.size).to eq(6)
    end

    it "puts a single engaged item in the highest tier" do
      only = observe(name: "Trampoline", duration: 45, frequency: 2)

      described_class.call(preference_assessment: assessment)

      expect(only.reload.tier).to eq("highest")
    end

    it "always marks an unengaged item low, whatever its position" do
      engaged   = observe(name: "Swing", duration: 30, frequency: 1)
      unengaged = observe(name: "Beads", duration: 0,  frequency: 0)

      described_class.call(preference_assessment: assessment)

      expect(engaged.reload.tier).to eq("highest")
      expect(unengaged.reload.tier).to eq("low")
      expect(unengaged.rank).to eq(2)
    end

    it "sorts every engaged item ahead of every unengaged one" do
      unengaged = observe(name: "Aardvark toy", duration: 0, frequency: 0)
      engaged   = observe(name: "Zebra toy",    duration: 1, frequency: 0)

      described_class.call(preference_assessment: assessment)

      expect(engaged.reload.rank).to eq(1)
      expect(unengaged.reload.rank).to eq(2)
    end
  end

  it "returns a successful result and leaves empty contexts alone" do
    result = described_class.call(preference_assessment: assessment)

    expect(result).to be_success
    expect(assessment.preference_observations).to be_empty
  end
end
