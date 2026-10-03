class AllowPartialStudentsForEnrollmentWizard < ActiveRecord::Migration[8.1]
  def change
    # The enrollment wizard persists a blank draft student first and fills the
    # required attributes in later steps, so these columns cannot be NOT NULL.
    # Completeness is still enforced by Student validations and by
    # Student#required_fields_present? before an enrollment can be completed.
    change_column_null :students, :first_name, true
    change_column_null :students, :last_name, true
    change_column_null :students, :date_of_birth, true
    change_column_null :students, :program_type, true
    change_column_null :students, :therapy_group, true
  end
end
