class CreateIups < ActiveRecord::Migration[8.1]
  def change
    create_table :iups, id: :uuid do |t|
      t.references :student, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: "draft"
      t.date :finalized_on
      t.timestamps
    end
  end
end
