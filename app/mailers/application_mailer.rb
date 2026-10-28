class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "notifications@timbre.dallo.dev")
  layout "mailer"
end
