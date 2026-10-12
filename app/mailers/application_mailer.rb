# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { AppConfig.dig(:mailer, :sender_email) }
  layout "mailer"
end
