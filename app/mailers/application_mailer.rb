# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { email_address_with_name(AppConfig.dig(:mailer, :sender_email), AppConfig.dig(:app_name)) }
  layout "mailer"
end
