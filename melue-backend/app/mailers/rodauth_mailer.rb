class RodauthMailer < ApplicationMailer
    def reset_password(email, reset_password_url)
        @reset_password_url = reset_password_url
        mail to: email, subject: "Reset Your Password"
    end
end
