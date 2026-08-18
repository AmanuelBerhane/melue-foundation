# frozen_string_literal: true

class CreateAbllsResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :ablls_responses, id: :uuid do |t|
      t.references :ablls_assessment, type: :uuid, null: false, foreign_key: true
      t.references :ablls_skill_item, type: :uuid, null: false, foreign_key: true
      t.string :score   # nil = unanswered; '0', '1', '2', 'not_applicable'
      t.text   :note

      t.timestamps
    end

    # One response per assessment + skill item
    add_index :ablls_responses,
              %i[ablls_assessment_id ablls_skill_item_id],
              unique: true,
              name: "idx_ablls_responses_unique_assessment_item"

    # Check constraint: score must be a valid value or null (unanswered)
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE ablls_responses
          ADD CONSTRAINT chk_ablls_response_score_valid
          CHECK (score IS NULL OR score IN ('0', '1', '2', 'not_applicable'));
        SQL
      end

      dir.down do
        execute <<~SQL
          ALTER TABLE ablls_responses
          DROP CONSTRAINT IF EXISTS chk_ablls_response_score_valid;
        SQL
      end
    end
  end
end
