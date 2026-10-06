# frozen_string_literal: true

class AddCustomFieldsToStudents < ActiveRecord::Migration[8.1]
  def change
    add_column :students, :custom_fields, :jsonb, default: {}, null: false
  end
end
