# frozen_string_literal: true

class CreateInternalStudentNotes < ActiveRecord::Migration[8.0]
  def change
    # NOTE: internal_student_notes.id is uuid (matching other clinical tables)
    #       student_id is uuid (students.id is uuid)
    #       author_id is bigint (users.id is bigint — default Rails PK)
    create_table :internal_student_notes, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :student, null: false, foreign_key: true, type: :uuid, index: true
      t.references :author,  null: false, foreign_key: { to_table: :users }, type: :bigint, index: true
      t.text :content,     null: false
      t.datetime :recorded_at, null: false

      t.timestamps
    end

    add_index :internal_student_notes, [:student_id, :recorded_at]
  end
end
