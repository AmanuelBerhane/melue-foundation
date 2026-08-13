class UpdateStudentsForEnrollmentWizard < ActiveRecord::Migration[8.1]
  def change
    # Add missing columns
    add_column :students, :guardian_email, :string unless column_exists?(:students, :guardian_email)
    add_column :students, :enrolled_at, :datetime unless column_exists?(:students, :enrolled_at)
    add_column :students, :assessment_started_at, :datetime unless column_exists?(:students, :assessment_started_at)
  end
end
