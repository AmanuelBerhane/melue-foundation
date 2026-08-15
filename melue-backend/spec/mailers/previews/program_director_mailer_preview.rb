# Preview all emails at http://localhost:3000/rails/mailers/program_director_mailer
class ProgramDirectorMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/program_director_mailer/mastery_check_submitted
  def mastery_check_submitted
    ProgramDirectorMailer.mastery_check_submitted
  end
end
