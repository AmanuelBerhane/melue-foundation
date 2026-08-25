class CreateStudentDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :student_documents do |t|
      # Use bigint to match students.id type
      t.references :student, type: :uuid, null: false, foreign_key: true

      t.string :document_type, null: false
      t.text :description

      t.timestamps
    end

    add_index :student_documents, :document_type
  end
end
