class AddDescriptionToRoles < ActiveRecord::Migration[8.1]
  def change
    add_column :roles, :description, :text
  end
end
