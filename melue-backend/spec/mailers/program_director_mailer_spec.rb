require "rails_helper"

RSpec.describe ProgramDirectorMailer, type: :mailer do
  describe "mastery_check_submitted" do
    let(:mail) { ProgramDirectorMailer.mastery_check_submitted }

    it "renders the headers" do
      expect(mail.subject).to eq("Mastery check submitted")
      expect(mail.to).to eq([ "to@example.org" ])
      expect(mail.from).to eq([ "from@example.com" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end
end
