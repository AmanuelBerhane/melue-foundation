class CreatePreferenceObservations < ActiveRecord::Migration[8.1]
  # Exactly one of: catalogue item, or custom item name (FR-047f).
  ITEM_XOR_CUSTOM = <<~SQL.squish
    (preference_inventory_item_id IS NOT NULL AND custom_item_name IS NULL)
    OR (preference_inventory_item_id IS NULL AND custom_item_name IS NOT NULL)
  SQL

  def change
    create_table :preference_observations, id: :uuid do |t|
      t.references :preference_assessment, null: false, foreign_key: true, type: :uuid

      # Nullable: a NULL item marks a teacher-supplied custom item (FR-047f),
      # which is recorded on the observation and never written back to the
      # global catalogue.
      t.references :preference_inventory_item, null: true, foreign_key: true, type: :uuid

      t.string :context, null: false

      # Approached / Did-Not-Approach — the primary field on the paper form.
      t.boolean :approached, null: false, default: false

      # Timer and counter totals (FR-047b).
      t.integer :duration_seconds, null: false, default: 0
      t.integer :frequency_count, null: false, default: 0

      # Derived by PreferenceAssessments::RankObservationsService (FR-047c, FR-048).
      t.decimal :combined_score, precision: 8, scale: 3, null: false, default: 0
      t.string :tier
      t.integer :rank

      # Custom item details (FR-047f) — only populated when the item FK is NULL.
      t.string :custom_item_name
      t.string :custom_item_category

      t.text :notes

      t.timestamps

      # A catalogue item may appear at most once per context within an assessment.
      # Custom items are excluded here because NULLs never collide in a unique
      # index; they get their own partial index below.
      t.index [ :preference_assessment_id, :context, :preference_inventory_item_id ],
              unique: true,
              where: "preference_inventory_item_id IS NOT NULL",
              name: "idx_pref_obs_unique_item_per_context"

      t.index [ :preference_assessment_id, :context, :custom_item_name ],
              unique: true,
              where: "preference_inventory_item_id IS NULL",
              name: "idx_pref_obs_unique_custom_per_context"

      # Supports the ranked-list read path (FR-047d).
      t.index [ :preference_assessment_id, :context, :rank ],
              name: "idx_pref_obs_rankings"

      t.check_constraint "duration_seconds >= 0",
                         name: "chk_pref_obs_duration_non_negative"
      t.check_constraint "frequency_count >= 0",
                         name: "chk_pref_obs_frequency_non_negative"
      t.check_constraint ITEM_XOR_CUSTOM,
                         name: "chk_pref_obs_item_xor_custom"
    end
  end
end
