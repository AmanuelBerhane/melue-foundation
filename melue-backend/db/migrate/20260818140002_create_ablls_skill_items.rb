# frozen_string_literal: true

class CreateAbllsSkillItems < ActiveRecord::Migration[8.1]
  def change
    create_table :ablls_skill_items, id: :uuid do |t|
      t.references :ablls_domain, type: :uuid, null: false, foreign_key: true
      t.string  :identifier,   null: false
      t.text    :description,  null: false
      t.integer :position,     null: false
      t.boolean :is_active,    null: false, default: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :ablls_skill_items, :identifier, unique: true
    add_index :ablls_skill_items, :position
    add_index :ablls_skill_items, :is_active
    add_index :ablls_skill_items, :discarded_at
  end
end
