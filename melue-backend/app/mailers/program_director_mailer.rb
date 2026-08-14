class ProgramDirectorMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.program_director_mailer.mastery_check_submitted.subject
  #
  def mastery_check_submitted
    @greeting = "Hi"

    mail to: "to@example.org"
  end
end
