# frozen_string_literal: true

class AddPhoneToStaffMembers < ActiveRecord::Migration[8.1]
  def change
    add_column :staff_members, :phone, :string
  end
end
