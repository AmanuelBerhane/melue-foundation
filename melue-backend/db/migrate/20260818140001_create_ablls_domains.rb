# frozen_string_literal: true

class CreateAbllsDomains < ActiveRecord::Migration[8.1]
  def change
    create_table :ablls_domains, id: :uuid do |t|
      t.string  :code,        null: false
      t.string  :name,        null: false
      t.text    :description
      t.integer :position,    null: false
      t.boolean :is_active,   null: false, default: true
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :ablls_domains, :code, unique: true
    add_index :ablls_domains, :position
    add_index :ablls_domains, :is_active
    add_index :ablls_domains, :discarded_at
  end
end
